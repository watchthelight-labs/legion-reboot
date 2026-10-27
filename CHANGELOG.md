# Changelog

## Unreleased

- `legion-reboot.sh` refuses (exit 4) while another `claude` session runs outside its own process chain; a restart cut two such sessions off on the Legion (2026-10-22). `REBOOT_OTHERS_PROCS` and `REBOOT_OTHERS_OK` in the config.
- `examples/claude-autostart.command` closes idle Terminal windows left from before the reboot and keeps its own window in front.

## 0.1.2

- iTerm2 is in the default keep list next to Terminal. The quit step used to close it, and with it the session running the script, so the restart never happened (Legion N-187, 2026-10-20).

## 0.1.1

- The autostart example keeps Claude Code's permission prompts by default; `--dangerously-skip-permissions` is an opt-in line in the config.

## 0.1.0 (2026-10-19)

- First public version of the scripts used on the Legion 5 15IAX10 Hackintosh since 2026-10-17.
- Settings through `~/.config/legion-reboot/config` or the environment instead of fixed paths: state folder, repo to check, check command, apps to keep, boot guards.
- Boot guard lines are printed only for guards that left a `pending.json`.
- The password is read silently from a terminal; an empty one uses `sudo -n` for a sudoers rule. A failed shutdown removes the pending attempt and exits 4.
