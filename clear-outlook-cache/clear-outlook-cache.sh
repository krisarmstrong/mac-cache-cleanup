#!/bin/bash
#
# clear-outlook-cache.sh
# Quits Microsoft Outlook, deletes its Caches + WebKit data, and relaunches
# Outlook. Intended to run daily via launchd.
#
# Deletion is direct (rm) — items are NOT routed through the Trash, so the
# user's Trash is never touched. This is safe because these are regenerable
# cache/WebKit data that Outlook recreates on next launch.
#
# Manual final step (cannot be automated): test the Dynamics App in Outlook.
#
# Author:  Kris Armstrong <kris.armstrong@icloud.com>
# License: Apache-2.0 (SPDX-License-Identifier: Apache-2.0) — see LICENSE
# Repo:    ~/Developer/mac-cache-cleanup/clear-outlook-cache
# Created: 2026-06-02
#
set -uo pipefail

# ---- Config -----------------------------------------------------------------
# Everything derives from HOME_DIR. $HOME auto-adapts to whoever runs the
# script, so normally you change NOTHING. To target a different account,
# set HOME_DIR to that user's home (e.g. HOME_DIR="/Users/someone").
HOME_DIR="${HOME}"

CONTAINER="$HOME_DIR/Library/Containers/com.microsoft.Outlook/Data/Library"
CACHES_DIR="$CONTAINER/Caches"
WEBKIT_DIR="$CONTAINER/Application Support/WebKit"
LOG="$HOME_DIR/Library/Logs/clear-outlook-cache.log"
# -----------------------------------------------------------------------------

log() { printf '%s  %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" >>"$LOG"; }

log "=== Starting Outlook cache cleanup ==="

# --- 1. Quit Outlook gracefully, then force-quit if it lingers ---------------
if pgrep -x "Microsoft Outlook" >/dev/null 2>&1; then
  log "Outlook running — requesting graceful quit"
  osascript -e 'tell application "Microsoft Outlook" to quit' >/dev/null 2>&1

  # Wait up to ~20s for a clean exit.
  for _ in $(seq 1 20); do
    pgrep -x "Microsoft Outlook" >/dev/null 2>&1 || break
    sleep 1
  done

  if pgrep -x "Microsoft Outlook" >/dev/null 2>&1; then
    log "Still running — force quitting"
    pkill -x "Microsoft Outlook" 2>/dev/null
    sleep 2
    pkill -9 -x "Microsoft Outlook" 2>/dev/null
    sleep 1
  fi
  log "Outlook is closed"
else
  log "Outlook was not running"
fi

# --- 2. Delete folder contents directly (no Trash) ---------------------------
clear_contents() {
  local dir="$1" label="$2" count=0
  if [ ! -d "$dir" ]; then
    log "$label folder does not exist — skipping ($dir)"
    return
  fi
  # Iterate all entries including dotfiles; nullglob so an empty dir is a
  # safe no-op (the glob expands to nothing rather than a literal '*').
  shopt -s dotglob nullglob
  for item in "$dir"/*; do
    if rm -rf -- "$item" 2>>"$LOG"; then
      count=$((count + 1))
    else
      log "Failed to delete: $item"
    fi
  done
  shopt -u dotglob nullglob
  log "$label: deleted $count item(s)"
}

clear_contents "$CACHES_DIR" "Caches"
clear_contents "$WEBKIT_DIR" "WebKit"

# --- 3. Relaunch Outlook -----------------------------------------------------
log "Relaunching Outlook"
open -a "Microsoft Outlook" 2>>"$LOG" || log "Failed to relaunch Outlook"

log "=== Cleanup complete (remember to test the Dynamics App) ==="
exit 0
