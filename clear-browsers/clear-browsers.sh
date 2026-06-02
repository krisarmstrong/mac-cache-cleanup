#!/bin/bash
#
# clear-browsers.sh
# Full daily wipe of cache + cookies + site data + history for Chrome, Edge,
# and Safari, then reopens whichever browsers were running.
#
# PRESERVED (NOT deleted): bookmarks, saved passwords, extensions, settings,
# autofill/search engines. We delete a curated allowlist of cache/cookie/
# storage/history items per profile — never the whole profile.
#
# CONSEQUENCES: you are logged out of every site in these browsers and all
# history is erased on each run. If browser Sync is on, the history/cookie
# deletion may propagate to your other devices.
#
# SAFARI requires Full Disk Access granted to /bin/bash (see README). Without
# it, the Safari steps fail with "Operation not permitted" — logged, not fatal.
#
# Author:  Kris Armstrong <kris.armstrong@icloud.com>
# License: Apache-2.0 (SPDX-License-Identifier: Apache-2.0) — see LICENSE
# Repo:    ~/Developer/clear-outlook-cache
# Created: 2026-06-02
#
set -uo pipefail

# ---- Config -----------------------------------------------------------------
# Everything derives from HOME_DIR. $HOME auto-adapts to whoever runs the
# script, so normally you change NOTHING. To target a different account,
# set HOME_DIR to that user's home (e.g. HOME_DIR="/Users/someone").
HOME_DIR="${HOME}"

LOG="$HOME_DIR/Library/Logs/clear-browsers.log"
# -----------------------------------------------------------------------------

log() { printf '%s  %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" >>"$LOG"; }

# rm -rf a path if it exists; log the outcome. Safe under `set -u`.
nuke() {
  local path="$1"
  [ -e "$path" ] || return 0
  if rm -rf -- "$path" 2>>"$LOG"; then
    log "  deleted: ${path/#$HOME_DIR/~}"
  else
    log "  FAILED (permission?): ${path/#$HOME_DIR/~}"
  fi
}

# Quit an app gracefully, then force-quit if it lingers. Echoes "was-running"
# to stdout if the app had been running (so the caller can relaunch it).
quit_app() {
  local proc="$1" appname="$2"
  if ! pgrep -x "$proc" >/dev/null 2>&1; then
    log "$appname: not running"
    return 0
  fi
  log "$appname: quitting"
  osascript -e "tell application \"$appname\" to quit" >/dev/null 2>&1
  for _ in $(seq 1 15); do
    pgrep -x "$proc" >/dev/null 2>&1 || break
    sleep 1
  done
  if pgrep -x "$proc" >/dev/null 2>&1; then
    log "$appname: force-quitting"
    pkill -x "$proc" 2>/dev/null
    sleep 2
    pkill -9 -x "$proc" 2>/dev/null
    sleep 1
  fi
  echo "was-running"
}

relaunch() {
  local appname="$1"
  log "$appname: relaunching"
  open -a "$appname" 2>>"$LOG" || log "$appname: relaunch failed"
}

# --- Chromium-family wipe (Chrome / Edge share this layout) ------------------
# $1 = browser support dir, $2 = top-level cache dir, $3 = label
wipe_chromium() {
  local support="$1" topcache="$2" label="$3"
  if [ ! -d "$support" ]; then
    log "$label: no profile dir ($support) — skipping"
    return 0
  fi

  # Top-level (non-profile) cache.
  nuke "$topcache"

  # Per-profile items. Default + numbered + Guest profiles.
  shopt -s nullglob
  local profiles=("$support/Default" "$support/Profile "* "$support/Guest Profile" "$support/System Profile")
  shopt -u nullglob

  local relpaths=(
    "Cache" "Code Cache" "GPUCache" "DawnCache" "GrShaderCache" "ShaderCache"
    "Service Worker" "IndexedDB" "Local Storage" "Session Storage"
    "Network/Cookies" "Network/Cookies-journal"
    "Cookies" "Cookies-journal"
    "History" "History-journal" "History-wal" "History-shm"
    "Top Sites" "Top Sites-journal"
    "Visited Links"
  )

  local p rel
  for p in "${profiles[@]}"; do
    [ -d "$p" ] || continue
    log "$label: wiping profile ${p##*/}"
    for rel in "${relpaths[@]}"; do
      nuke "$p/$rel"
    done
  done
  log "$label: done"
}

# --- Safari wipe (requires Full Disk Access) ---------------------------------
wipe_safari() {
  local container="$HOME_DIR/Library/Containers/com.apple.Safari/Data/Library"
  if [ ! -d "$HOME_DIR/Library/Safari" ] && [ ! -d "$container" ]; then
    log "Safari: not present — skipping"
    return 0
  fi
  log "Safari: wiping history, cache, cookies, site data"

  # History.
  nuke "$HOME_DIR/Library/Safari/History.db"
  nuke "$HOME_DIR/Library/Safari/History.db-wal"
  nuke "$HOME_DIR/Library/Safari/History.db-shm"
  nuke "$HOME_DIR/Library/Safari/History.db-lock"

  # Older on-disk site storage.
  nuke "$HOME_DIR/Library/Safari/LocalStorage"
  nuke "$HOME_DIR/Library/Safari/Databases"

  # Container: caches + WebKit storage (IndexedDB / localStorage / SW) + cookies.
  local sub
  shopt -s dotglob nullglob
  for sub in "$container/Caches/"* "$container/WebKit/"*; do
    nuke "$sub"
  done
  shopt -u dotglob nullglob
  nuke "$container/Cookies/Cookies.binarycookies"

  log "Safari: done (if entries say 'permission', grant Full Disk Access — see README)"
}

# --- Run ---------------------------------------------------------------------
main() {
  log "=== Starting browser full-wipe ==="

  local chrome_run edge_run safari_run
  chrome_run="$(quit_app 'Google Chrome' 'Google Chrome')"
  edge_run="$(quit_app 'Microsoft Edge' 'Microsoft Edge')"
  safari_run="$(quit_app 'Safari' 'Safari')"

  wipe_chromium "$HOME_DIR/Library/Application Support/Google/Chrome" \
                "$HOME_DIR/Library/Caches/Google/Chrome" "Chrome"
  wipe_chromium "$HOME_DIR/Library/Application Support/Microsoft Edge" \
                "$HOME_DIR/Library/Caches/Microsoft Edge" "Edge"
  wipe_safari

  # Reopen only the browsers that were running before the wipe.
  [ -n "$chrome_run" ] && relaunch "Google Chrome"
  [ -n "$edge_run" ]   && relaunch "Microsoft Edge"
  [ -n "$safari_run" ] && relaunch "Safari"

  log "=== Browser wipe complete ==="
}

# Only run when executed directly, not when sourced (so functions are testable).
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
