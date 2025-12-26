#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

BIN_DIR="$HOME/.local/bin"
PIN_BIN="$BIN_DIR/cursor-pin-openai-proxy"

LA_DIR="$HOME/Library/LaunchAgents"
PLIST="$LA_DIR/com.jiesen.cursor-openai-proxy-pin.plist"

log() { printf "%s %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >&2; }

mkdir -p "$BIN_DIR" "$LA_DIR"
install -m 0755 "$SCRIPT_DIR/cursor-pin.sh" "$PIN_BIN"

cat >"$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>com.jiesen.cursor-openai-proxy-pin</string>
  <key>ProgramArguments</key>
  <array>
    <string>$PIN_BIN</string>
    <string>--daemon</string>
    <string>3</string>
  </array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>StandardOutPath</key><string>$HOME/Library/Logs/cursor-openai-proxy-pin.log</string>
  <key>StandardErrorPath</key><string>$HOME/Library/Logs/cursor-openai-proxy-pin.log</string>
</dict>
</plist>
EOF

UID_NUM="$(id -u)"

set +e
launchctl bootout "gui/$UID_NUM" "com.jiesen.cursor-openai-proxy-pin" >/dev/null 2>&1
set -e

launchctl bootstrap "gui/$UID_NUM" "$PLIST"
launchctl enable "gui/$UID_NUM/com.jiesen.cursor-openai-proxy-pin" || true
launchctl kickstart -k "gui/$UID_NUM/com.jiesen.cursor-openai-proxy-pin"

log "Installed: $PIN_BIN"
log "Installed: $PLIST"
log "Log file:  $HOME/Library/Logs/cursor-openai-proxy-pin.log"

