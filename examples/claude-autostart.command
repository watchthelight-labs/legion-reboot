#!/bin/zsh
# <wtl> project: legion-reboot | file: examples/claude-autostart.command | author: watchthelight </wtl>
# Opens Claude Code at login in AUTOSTART_DIR and resumes the last session there. After a reboot that legion-reboot
# recorded, the first turn is a prompt to run the check for that attempt (reboot-detect.sh prints the details into
# the session). Started by examples/org.watchthelight.claude-autostart.plist through Terminal.
CONF=${LEGION_REBOOT_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/legion-reboot/config}
[ -f "$CONF" ] && . "$CONF"
export PATH="$HOME/.local/bin:$PATH"
S=${REBOOT_STATE:-$HOME/.cache/legion-reboot}
GUARDS=${REBOOT_GUARDS:-gpu-guard=${GPU_GUARD_STATE:-$HOME/.cache/gpu-guard} wifi-guard=${WIFI_GUARD_STATE:-$HOME/.cache/wifi-guard}}
RESULTS=${AUTOSTART_PROMPT_RESULTS:-rolled-back pass-after-rollback stuck failed-after-rollback}
ARGS=(${=AUTOSTART_CLAUDE_ARGS---dangerously-skip-permissions --verbose})
# not ~: Claude Code never saves folder trust for the home directory
cd "${AUTOSTART_DIR:?set AUTOSTART_DIR in the legion-reboot config}" || exit 1
mkdir -p "$S"
PROMPT=""
if [ -f "$S/pending.json" ]; then
  R=$(/usr/bin/python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(d["attempt"]); print(d.get("check",""))' "$S/pending.json" 2>/dev/null)
  ID=${R%%$'\n'*}; CHECK=${R#*$'\n'}; [ "$CHECK" = "$R" ] && CHECK=""
  PROMPT="The machine just rebooted for ${ID:-the pending attempt} (see the reboot-detect banner). Run ${CHECK:-the check for that attempt} now. ${AUTOSTART_NOTE:-}"
fi
# A guard that finished an attempt (rolled back, stuck) while no session could run gets one prompt per result.
# AUTOSTART_PROMPT_RESULTS lists the results that prompt; "any" prompts on every new result (useful for a guard whose
# boots have no network, so the session started during them never reached the API).
for g in ${=GUARDS}; do
  [ -n "$PROMPT" ] && break
  name=${g%%=*}; dir=${g#*=}; P="$dir/pending.json"; M="$S/reported-$name.txt"
  [ -f "$P" ] || continue
  R=$(/usr/bin/python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(d.get("attempt",""), d.get("result",""), d.get("reason",""))' "$P" 2>/dev/null)
  RES=$(echo "$R" | awk '{print $2}')
  [ -n "$RES" ] || continue
  [ "$RESULTS" = any ] || [[ " $RESULTS " == *" $RES "* ]] || continue
  [ "$R" = "$(cat "$M" 2>/dev/null)" ] && continue
  echo "$R" > "$M"
  PROMPT="The $name finished attempt $(echo "$R" | awk '{print $1}') with result '$RES' ($(echo "$R" | cut -d' ' -f3-)). This boot is the one after it. Read the guard's captures in $dir and record the result. ${AUTOSTART_NOTE:-}"
done
# --continue exits with an error when this folder has no earlier session, so fall back to a fresh one
if [ -n "$PROMPT" ]; then
  claude "${ARGS[@]}" --continue "$PROMPT" || exec claude "${ARGS[@]}" "$PROMPT"
else
  claude "${ARGS[@]}" --continue || exec claude "${ARGS[@]}"
fi
