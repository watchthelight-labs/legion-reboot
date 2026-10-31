#!/bin/bash
# <wtl> project: legion-reboot | file: reboot-detect.sh | author: watchthelight </wtl>
# Claude Code SessionStart hook. Compares the kernel boot time with the one the last session saw; on a change it
# prints a banner that lands in the new session's context, with the pending attempt from legion-reboot.sh if there
# is one, and the state of any boot guard that left a pending.json. Prints nothing when the machine has not rebooted.
# Read-only on the system: it only writes its own state folder.
CONF=${LEGION_REBOOT_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/legion-reboot/config}
[ -f "$CONF" ] && . "$CONF"
S=${REBOOT_STATE:-$HOME/.cache/legion-reboot}; mkdir -p "$S"
GUARDS=${REBOOT_GUARDS:-gpu-guard=${GPU_GUARD_STATE:-$HOME/.cache/gpu-guard} wifi-guard=${WIFI_GUARD_STATE:-$HOME/.cache/wifi-guard}}
NOW=$(sysctl -n kern.boottime | sed -E 's/^\{ sec = ([0-9]+),.*/\1/')
LAST=$(cat "$S/boottime.txt" 2>/dev/null || echo "")
echo "$NOW" > "$S/boottime.txt"
[ -z "$LAST" ] && { echo "[reboot-detect] first run: boot time recorded ($(date -r "$NOW" '+%Y-%m-%d %H:%M:%S')), uptime $(( ($(date +%s) - NOW) / 60 )) min"; exit 0; }
[ "$NOW" = "$LAST" ] && exit 0
UP=$(( ($(date +%s) - NOW) / 60 ))" min"
echo "[reboot-detect] REBOOT DETECTED: this macOS booted $(date -r "$NOW" '+%Y-%m-%d %H:%M:%S %Z') (uptime $UP); the previous session saw a boot at $(date -r "$LAST" '+%H:%M:%S')."
if [ -f "$S/pending.json" ]; then
  /usr/bin/python3 - "$S/pending.json" "$LAST" "$NOW" <<'PY'
import sys, json
p = json.load(open(sys.argv[1])); last, now = int(sys.argv[2]), int(sys.argv[3])
match = p.get("boottime_before") == last
check = p.get("check") or f"the check for {p['attempt']}"
print(f"[reboot-detect] pending attempt {p['attempt']} requested {p['requested_at']} from repo {p.get('repo_head') or '?'}: {p.get('reason','')}")
print(f"[reboot-detect] {'this is that reboot' if match else 'WARNING: the recorded boot time does not match, more than one restart happened'}; run {check} now.")
PY
  mv "$S/pending.json" "$S/last-$(date -r "$NOW" '+%Y%m%d-%H%M%S').json"
else
  echo "[reboot-detect] no pending attempt was recorded (a manual restart, a crash or a power cut); check the newest attempt."
fi
# Boot guards (for example github.com/watchthelight-labs/WTLGpuGuard and wifi-guard) keep their own pending.json;
# print a guard's line only when that file exists.
for g in $GUARDS; do
  name=${g%%=*}; dir=${g#*=}
  [ -f "$dir/pending.json" ] || continue
  /usr/bin/python3 - "$name" "$dir/pending.json" <<'PY'
import sys, json
name, path = sys.argv[1:3]
p = json.load(open(path))
label = f" ({p['label']})" if p.get("label") else ""
stage = f" stage {p['stage']}" if p.get("stage") else ""
recovery = f"; recovery {p['recovery']}" if p.get("recovery") else ""
print(f"[reboot-detect] {name}: attempt {p.get('attempt')}{label}{stage} result {p.get('result') or 'none yet (the guard may still be waiting for a confirmation, or rolls back after its window)'}; reason: {p.get('reason', '')}{recovery}; auto_reboots {p.get('auto_reboots', 0)}")
PY
done
echo "[reboot-detect] crash reports since boot: $(find /Library/Logs/DiagnosticReports ~/Library/Logs/DiagnosticReports -name '*.ips' -newermt "@$NOW" 2>/dev/null | wc -l | tr -d ' ') (panic*.ips = kernel panic)"
