# How legion-reboot works

## Detecting a reboot

`sysctl -n kern.boottime` gives the kernel's boot time as `{ sec = 1792430593, usec = ... }`. The seconds value is the same for the whole life of a boot and changes with every restart, so it identifies a boot without any daemon or login item.

`reboot-detect.sh` keeps the last value it saw in `boottime.txt` in the state folder (`REBOOT_STATE`, default `~/.cache/legion-reboot`). On every session start:

1. No `boottime.txt`: first run. It records the value and prints one line.
2. Same value: same boot, nothing printed. Claude Code starts sessions often (`startup`, `resume`, `clear`), so silence is the normal case.
3. Different value: `REBOOT DETECTED`, then the details below. The new value is written first, so the banner appears once per boot.

## The pending attempt

`legion-reboot.sh` writes `pending.json` before it restarts:

```json
{
 "attempt": "boot-42",
 "reason": "new framebuffer patch",
 "requested_at": "2026-10-19 13:21:40 EDT",
 "boottime_before": 1792430593,
 "repo": "/Users/you/src/project",
 "repo_head": "1dc999c",
 "check": "/boot-check boot-42"
}
```

and writes `boottime_before` to `boottime.txt` as well. After the restart, `reboot-detect.sh` compares `boottime_before` with the boot time the previous session saw. Equal: this is the reboot that was asked for. Different: the machine restarted more than once in between (a panic, a guard rollback, a manual restart), and the banner says so. Then `pending.json` is renamed to `last-<boot time>.json`, which keeps a history and makes sure the attempt is reported only once.

When the shutdown command fails, `legion-reboot.sh` deletes `pending.json` again, so a later real restart is not mistaken for that attempt. The on-screen confirmation (`REBOOT_ASK=1`) does the same on Cancel or after two minutes without an answer.

## The order of steps in legion-reboot.sh

1. Check the repo: `git status --porcelain` without the `??` lines. Anything left means staged or modified files, and it stops with exit 2.
2. Record `pending.json`.
3. Ask on screen if `REBOOT_ASK=1` (exit 3 without a yes).
4. Quit apps and clear the relaunch list (below).
5. `sync`, read the password, `shutdown -r now "legion-reboot <id>: <reason>"`. The message ends up in the system log.

## Apps coming back after the restart

macOS reopens the apps that were running at shutdown. For a boot test that means a desktop full of apps fighting for the GPU while the new driver comes up. The script asks System Events for every non-background app and tells each one to quit, except the ones in `REBOOT_KEEP_APPS` (Terminal and Finder by default; the agent's own terminal must stay or the script dies with it).

On macOS 26 the relaunch list lives in `~/Library/Group Containers/group.com.apple.loginwindow.persistent-apps/persistantApps` (Apple's spelling), and loginwindow rewrites it a few seconds after an app quits. A restart one second after the quits still brought the apps back from the old list. So the script waits 8 seconds, then deletes that file, deletes `TALAppsToRelaunchAtLogin` and sets `TALLogoutSavesState` to false in `com.apple.loginwindow` (current host).

## The password

```
read -r PW                                   # read -rs with a prompt when stdin is a terminal
printf '%s\n' "$PW" | sudo -S -p '' /sbin/shutdown -r now "$MSG"
unset PW
```

`printf` is a bash builtin, so the password is never the argument of a separate process and never shows up in `ps`. The script has no `set -x`. An empty password switches to `sudo -n`, which works with a NOPASSWD sudoers rule or a cached sudo timestamp and fails at once otherwise.

When the agent supplies the password, it has to get it from somewhere; keep it in a credential store the agent can read, never in the repo or the agent's instructions. A sudoers rule for `/sbin/shutdown -r now *` avoids the question.

## Boot guards

`REBOOT_GUARDS` is a space-separated list of `name=folder` pairs. For each one whose `folder/pending.json` exists, `reboot-detect.sh` prints the fields `attempt`, `label`, `stage`, `result`, `reason`, `recovery` and `auto_reboots` when present. `examples/claude-autostart.command` reads the same files and starts the session with a prompt when a guard's result is one of `AUTOSTART_PROMPT_RESULTS` (default: `rolled-back`, `pass-after-rollback`, `stuck`, `failed-after-rollback`), once per result: the last one it prompted for is kept in `reported-<name>.txt` in the legion-reboot state folder.

## The autostart

A LaunchAgent opens Terminal at login with `claude-autostart.command`. That changes to `AUTOSTART_DIR` (Claude Code does not save folder trust for the home directory, so it has to be a project folder) and runs `claude --continue "<prompt>"` when there is something to check, else `claude --continue`. `--continue` fails when the folder has no earlier session, and the script then starts a new one with the same prompt.
