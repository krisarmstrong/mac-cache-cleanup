#!/bin/bash
#
# install.sh — install (or update) the daily browser full-wipe.
# Quits Chrome/Edge/Safari, wipes cache + cookies + site data + history,
# reopens only the browsers that were running. Daily 06:00. Idempotent.
#
#   ./install.sh            # install / update
#   ./install.sh uninstall  # remove job + installed script
#
# NOTE: Safari needs Full Disk Access granted to /bin/bash — see README.
#
# Author:  Kris Armstrong <kris.armstrong@icloud.com>
# License: Apache-2.0 (SPDX-License-Identifier: Apache-2.0) — see LICENSE
#
set -euo pipefail

# ---- Config -----------------------------------------------------------------
# Install locations derive from HOME_DIR. $HOME auto-adapts to whoever runs
# the installer, so normally you change NOTHING. To install for a different
# account, set HOME_DIR to that user's home. LABEL is just a unique job id.
HOME_DIR="${HOME}"
LABEL="com.krisarmstrong.clearbrowsers"
SCRIPT="clear-browsers.sh"
HOUR=6
MINUTE=0
# -----------------------------------------------------------------------------

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$HOME_DIR/Library/Scripts"
AGENTS_DIR="$HOME_DIR/Library/LaunchAgents"
LOGS_DIR="$HOME_DIR/Library/Logs"
SRC_SCRIPT="$REPO_DIR/$SCRIPT"
DEST_SCRIPT="$SCRIPTS_DIR/$SCRIPT"
PLIST="$AGENTS_DIR/$LABEL.plist"
UID_NUM="$(id -u)"

if [ "${1:-}" = "uninstall" ]; then
  launchctl bootout "gui/$UID_NUM/$LABEL" 2>/dev/null || true
  rm -f "$PLIST" "$DEST_SCRIPT"
  echo "Uninstalled $LABEL (logs in $LOGS_DIR left intact)."
  exit 0
fi

[ -f "$SRC_SCRIPT" ] || { echo "ERROR: $SRC_SCRIPT not found" >&2; exit 1; }
mkdir -p "$SCRIPTS_DIR" "$AGENTS_DIR" "$LOGS_DIR"

echo "Installing script → $DEST_SCRIPT"
cp "$SRC_SCRIPT" "$DEST_SCRIPT"
chmod +x "$DEST_SCRIPT"

echo "Writing launchd job → $PLIST"
cat >"$PLIST" <<PLIST_EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$LABEL</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>$DEST_SCRIPT</string>
    </array>
    <!-- Daily at $HOUR:$(printf '%02d' "$MINUTE"). If the Mac is off/asleep then,
         launchd runs the missed job once after it next boots/wakes. -->
    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key><integer>$HOUR</integer>
        <key>Minute</key><integer>$MINUTE</integer>
    </dict>
    <key>StandardOutPath</key>
    <string>$LOGS_DIR/clear-browsers.out.log</string>
    <key>StandardErrorPath</key>
    <string>$LOGS_DIR/clear-browsers.err.log</string>
</dict>
</plist>
PLIST_EOF

plutil -lint "$PLIST"
launchctl bootout "gui/$UID_NUM/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$UID_NUM" "$PLIST"

echo
echo "Installed and scheduled (daily $HOUR:$(printf '%02d' "$MINUTE"))."
echo "  Run now:    launchctl kickstart -k gui/$UID_NUM/$LABEL"
echo "  Watch log:  tail -f $LOGS_DIR/clear-browsers.log"
echo "  Uninstall:  $REPO_DIR/install.sh uninstall"
echo
echo "REMINDER: grant Full Disk Access to /bin/bash for the Safari wipe (README)."
