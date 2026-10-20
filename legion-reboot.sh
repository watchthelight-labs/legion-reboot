#!/bin/bash
# <wtl> project: legion-reboot | file: legion-reboot.sh | author: watchthelight </wtl>
# Restart this Mac for a staged boot attempt. Records the pending attempt first so the next Claude Code session
# (SessionStart hook: reboot-detect.sh) knows a reboot happened, why, and which check to run.
#   printf '%s\n' "<sudo password>" | legion-reboot.sh <attempt id> "why this boot"   [--force to ignore uncommitted changes]
#   legion-reboot.sh <attempt id> "why" </dev/null       (with a sudoers rule for shutdown, no password)
# The password is read from stdin once, handed to sudo through a pipe and never written anywhere.
# Never pass it as an argument: arguments are visible to every process through ps.
# Settings: ${XDG_CONFIG_HOME:-~/.config}/legion-reboot/config (see config.example) or the environment.
set -u
CONF=${LEGION_REBOOT_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/legion-reboot/config}
[ -f "$CONF" ] && . "$CONF"
S=${REBOOT_STATE:-$HOME/.cache/legion-reboot}
REPO=${REBOOT_REPO:-$(git rev-parse --show-toplevel 2>/dev/null)}
[ "$REPO" = none ] && REPO=""
CHECK=${REBOOT_CHECK:-}
KEEP=${REBOOT_KEEP_APPS:-Terminal,iTerm2,Finder,System Events}

ID=${1:?usage: legion-reboot.sh <attempt id> [reason] [--force]}; REASON=${2:-}; FORCE=${3:-}
mkdir -p "$S"
if [ -n "$REPO" ] && [ -z "$FORCE" ] && [ -n "$(git -C "$REPO" status --porcelain 2>/dev/null | grep -v '^??')" ]; then
  echo "REFUSED: uncommitted changes in $REPO (commit first, or pass --force as the third argument)"; git -C "$REPO" status --short | head; exit 2
fi
[ -z "$REPO" ] && echo "note: no git repository to check (set REBOOT_REPO); restarting without the uncommitted-changes check"
BOOT=$(sysctl -n kern.boottime | sed -E 's/^\{ sec = ([0-9]+),.*/\1/')
/usr/bin/python3 - "$ID" "$REASON" "$BOOT" "$S/pending.json" "$REPO" "$CHECK" <<'PY'
import sys, json, time, subprocess
aid, reason, boot, path, repo, check = sys.argv[1:7]
head = subprocess.run(["git", "-C", repo, "rev-parse", "--short", "HEAD"], capture_output=True, text=True).stdout.strip() if repo else ""
json.dump({"attempt": aid, "reason": reason, "requested_at": time.strftime("%Y-%m-%d %H:%M:%S %Z"), "boottime_before": int(boot),
           "repo": repo, "repo_head": head, "check": check.replace("{id}", aid)}, open(path, "w"), indent=1)
print(f"pending {aid} recorded ({path}), boot before = {time.strftime('%H:%M:%S', time.localtime(int(boot)))}, repo {head or 'none'}")
PY
# REBOOT_ASK=1 shows an on-screen question first (Reboot / Cancel, two minutes) and aborts without a yes, for times
# when a person should approve every restart.
if [ "${REBOOT_ASK:-0}" = 1 ]; then
  ANSWER=$(osascript -e "display dialog \"Claude Code wants to restart this Mac for $ID.\n\n$REASON\n\nOK to reboot now?\" buttons {\"Cancel\", \"Reboot\"} default button \"Reboot\" cancel button \"Cancel\" with title \"Reboot $ID\" with icon caution giving up after 120" 2>/dev/null)
  case "$ANSWER" in *"button returned:Reboot"*"gave up:false"*) ;; *) echo "REBOOT NOT CONFIRMED ($ID): ${ANSWER:-dialog cancelled or closed}"; rm -f "$S/pending.json"; exit 3 ;; esac
fi
echo "$BOOT" > "$S/boottime.txt"
# Quit the user's apps first and drop loginwindow's relaunch list, so a restart for a boot attempt does not bring
# every app back at login. The apps in REBOOT_KEEP_APPS (the terminal running this session among them) stay.
if [ "${REBOOT_QUIT_APPS:-1}" = 1 ]; then
  KEEPLIST=$(printf '%s' "$KEEP" | sed -E 's/[[:space:]]*,[[:space:]]*/", "/g; s/^/"/; s/$/"/')
  osascript -e 'tell application "System Events" to set names to name of every application process whose background only is false' \
    -e 'repeat with n in names' -e "if n is not in {$KEEPLIST, \"System Events\"} then" \
    -e 'try' -e 'tell application n to quit' -e 'end try' -e 'end if' -e 'end repeat' >/dev/null 2>&1
  # macOS 26 keeps the relaunch list in a group container and rewrites it a few seconds after an app quits; give that
  # timer time, then drop the list as well (a restart 1 s after the quits still relaunched the apps from the old list).
  sleep 8
  rm -f "$HOME/Library/Group Containers/group.com.apple.loginwindow.persistent-apps/persistantApps"
  defaults -currentHost delete com.apple.loginwindow TALAppsToRelaunchAtLogin >/dev/null 2>&1
  defaults -currentHost write com.apple.loginwindow TALLogoutSavesState -bool false
fi
sync
MSG="legion-reboot $ID: $REASON"
# Password from stdin, silently when stdin is a terminal. An empty one means sudo must work without a password
# (a sudoers rule for shutdown, or a cached sudo timestamp).
PW=""
if [ -t 0 ]; then read -rs -p "sudo password (empty if sudoers allows shutdown): " PW; echo; else read -r PW || true; fi
if [ -n "$PW" ]; then
  printf '%s\n' "$PW" | sudo -S -p '' /sbin/shutdown -r now "$MSG" 2>&1 | grep -v "^$"; RC=${PIPESTATUS[1]}
else
  sudo -n /sbin/shutdown -r now "$MSG" 2>&1 | grep -v "^$"; RC=${PIPESTATUS[0]}
fi
unset PW
if [ "$RC" -ne 0 ]; then
  echo "FAILED: shutdown exited $RC (wrong password, or no sudoers rule); the pending attempt $ID was removed"
  rm -f "$S/pending.json"; exit 4
fi
