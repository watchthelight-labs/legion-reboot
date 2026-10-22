# legion-reboot

Two small shell scripts that let an AI coding agent (Claude Code here) restart the Mac it is running on for a staged boot attempt, and tell the next session that the restart happened and why.

## The problem

When the agent works on the machine it is testing (a Hackintosh, a kext, a boot config), every test ends with a reboot, and the reboot ends the session. The next session starts with no idea that a reboot just happened, which attempt it was for, or what to check. If something else restarted the machine in between (a panic, a guard rolling back a driver, a power cut), it should know that too.

- `legion-reboot.sh <id> "<reason>"` refuses to restart while the project repo has uncommitted changes, writes the pending attempt (id, reason, time, boot time, repo commit, the check to run) to `pending.json`, quits the open apps so they do not all come back at login, and runs `shutdown -r now`.
- `reboot-detect.sh` is a Claude Code SessionStart hook. It compares the kernel boot time with the one the last session saw. Same boot: it prints nothing. New boot: it prints a `REBOOT DETECTED` banner with the pending attempt, a warning if more than one restart happened since it was recorded, the result of any boot guard that left a state file, and the number of crash reports since boot. Hook output lands in the session's context, so the agent reads it before your first message.

`examples/claude-autostart.command` (optional) opens Terminal at login and resumes the last Claude Code session with a prompt to run the check, so the work goes on without anyone typing.

## Status

In daily use on a Lenovo Legion 5 15IAX10 Hackintosh (macOS 26.7.1, 25G241) since 2026-10-17: by 2026-10-19 it had recorded 77 boot attempts for GPU, Wi-Fi and CPU driver work.

## Install

Needs macOS with the Xcode Command Line Tools (for `/usr/bin/python3` and `git`).

```
git clone https://github.com/watchthelight-labs/legion-reboot ~/src/legion-reboot
~/src/legion-reboot/install.sh          # links legion-reboot and reboot-detect into ~/.local/bin, copies the config
```

Settings live in `~/.config/legion-reboot/config` (copied from `config.example`, every value documented there): the state folder (default `~/.cache/legion-reboot`), the repo to check (default: the git repo of the current directory), the check command for the next session (`{id}` is replaced), the on-screen confirmation, which apps stay open, and the boot guards to report.

Then add the hook to `~/.claude/settings.json` (or a project's `.claude/settings.json`):

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|resume|clear",
        "hooks": [
          { "type": "command", "command": "/Users/you/.local/bin/reboot-detect", "timeout": 10 }
        ]
      }
    ]
  }
}
```

Run `reboot-detect` once by hand: the first run records the boot time and says so.

For the autostart, `./install.sh --autostart` installs `claude-autostart.command` and a LaunchAgent that runs it at login; set `AUTOSTART_DIR` in the config to the folder the agent works in. Its default arguments include `--dangerously-skip-permissions`, because that is what lets an unattended session do anything. Set `AUTOSTART_CLAUDE_ARGS="--verbose"` if you want the prompts.

## Usage

```
printf '%s\n' "$PW" | legion-reboot boot-42 "new framebuffer patch"     # sudo password on stdin
legion-reboot boot-42 "new framebuffer patch" </dev/null               # with a sudoers rule (below)
legion-reboot boot-42 "retry" --force                                    # skip the uncommitted-changes check
REBOOT_ASK=1 legion-reboot boot-42 "..."                                 # ask on screen first
```

The attempt id is a free-form label; use whatever your notes use. Tell the agent in your project instructions to restart only through `legion-reboot` and to run the check when it sees `REBOOT DETECTED`.

After the restart, the next session starts with something like:

```
[reboot-detect] REBOOT DETECTED: this macOS booted 2026-10-19 13:23:13 EDT (uptime 2 min); the previous session saw a boot at 11:02:51.
[reboot-detect] pending attempt boot-42 requested 2026-10-19 13:21:40 EDT from repo 1dc999c: new framebuffer patch
[reboot-detect] this is that reboot; run /boot-check boot-42 now.
[reboot-detect] crash reports since boot: 0 (panic*.ips = kernel panic)
```

### Boot guards

A guard is a boot-time daemon that watches a risky boot and rolls it back on its own when nobody confirms it. [gpu-guard](https://github.com/watchthelight-labs/gpu-guard) and [wifi-guard](https://github.com/watchthelight-labs/wifi-guard) work that way. Each keeps a `pending.json` with the attempt, its result and the reason. `reboot-detect.sh` prints one line per guard listed in `REBOOT_GUARDS` whose `pending.json` exists, and skips the rest, so without guards you see nothing extra.

## Safety

- **Uncommitted changes stop it.** With modified or staged files in the repo it exits with `REFUSED` and restarts nothing. Untracked files do not count. `--force` skips the check.
- **The password.** It is read from stdin once (silently if stdin is a terminal), piped to `sudo -S` and unset. It never appears in an argument, a file, `pending.json` or the output. `sudo -p ''` keeps the prompt out of the log. If the shutdown fails (wrong password, no rule), it removes the pending attempt and exits 4, so the next session is not told about a restart that never happened.
- **A sudoers rule is cleaner** than handing the agent your password. Add this rule with `sudo visudo -f /etc/sudoers.d/shutdown` (replace `you` with your user name) and call `legion-reboot` with no password at all:

  ```
  you ALL=(root) NOPASSWD: /sbin/shutdown -r now *
  ```

- **Quitting apps.** By default every GUI app except Terminal, iTerm2 and Finder is asked to quit (unsaved work gets the usual prompt and that app stays open), and the login relaunch list is cleared. `REBOOT_QUIT_APPS=0` turns that off; `REBOOT_KEEP_APPS` lists what stays.
- `reboot-detect.sh` is read-only on the system; it writes only its state folder.

## How it works

[docs/HOW-IT-WORKS.md](docs/HOW-IT-WORKS.md): the state files, how a reboot is detected, and the relaunch-list detail on macOS 26.

## Licence

ISC, see [LICENSE](LICENSE).
