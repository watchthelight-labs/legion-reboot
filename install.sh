#!/bin/bash
# <wtl> project: legion-reboot | file: install.sh | author: watchthelight </wtl>
# Links legion-reboot and reboot-detect into ~/.local/bin and copies the example config if there is none. No sudo.
#   ./install.sh               the two scripts
#   ./install.sh --autostart   also claude-autostart.command and its LaunchAgent (loaded at the next login)
set -e
cd "$(dirname "$0")"
BIN=$HOME/.local/bin; CONFDIR=${XDG_CONFIG_HOME:-$HOME/.config}/legion-reboot
mkdir -p "$BIN" "$CONFDIR"
chmod 755 legion-reboot.sh reboot-detect.sh examples/claude-autostart.command
ln -sf "$PWD/legion-reboot.sh" "$BIN/legion-reboot"
ln -sf "$PWD/reboot-detect.sh" "$BIN/reboot-detect"
[ -f "$CONFDIR/config" ] || cp config.example "$CONFDIR/config"
echo "linked $BIN/legion-reboot and $BIN/reboot-detect; config in $CONFDIR/config"
if [ "${1:-}" = --autostart ]; then
  install -m 755 examples/claude-autostart.command "$BIN/claude-autostart.command"
  sed "s|HOME_DIR|$HOME|" examples/org.watchthelight.claude-autostart.plist > "$HOME/Library/LaunchAgents/org.watchthelight.claude-autostart.plist"
  echo "autostart installed; set AUTOSTART_DIR in $CONFDIR/config, it runs at the next login"
fi
echo "now add $BIN/reboot-detect as a SessionStart hook in ~/.claude/settings.json (see README.md)"
