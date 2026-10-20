# Changelog

## 0.1.1

- The autostart example keeps Claude Code's permission prompts by default; `--dangerously-skip-permissions` is an opt-in line in the config.

## 0.1.0 (2026-10-19)

- First public version of the scripts used on the Legion 5 15IAX10 Hackintosh since 2026-10-17.
- Settings through `~/.config/legion-reboot/config` or the environment instead of fixed paths: state folder, repo to check, check command, apps to keep, boot guards.
- Boot guard lines are printed only for guards that left a `pending.json`.
- The password is read silently from a terminal; an empty one uses `sudo -n` for a sudoers rule. A failed shutdown removes the pending attempt and exits 4.
