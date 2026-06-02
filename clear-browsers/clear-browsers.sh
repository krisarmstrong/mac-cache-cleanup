#!/bin/bash
#
# clear-browsers.sh
# Daily cleanup of Chrome, Edge, and Safari, then reopens whichever browsers
# were running. Two modes:
#
#   (default) light  — clear caches + service workers only. You stay LOGGED IN;
#                      cookies, local storage, and history are kept. Fixes stale
#                      web content without a daily re-login.
#   --full           — also wipe cookies + site storage + history (logs you out
#                      of every site, erases history). The original behavior.
#   --only <list>    — only act on these browsers (comma-separated: chrome,edge,
#                      safari). Default: all installed ones. Browsers that aren't
#                      installed are skipped automatically regardless.
#   --dry-run, -n    — report what WOULD be deleted (with sizes); delete nothing
#                      and do not quit/relaunch anything.
#
# PRESERVED in BOTH modes: bookmarks, saved passwords, extensions, settings,
# autofill/search engines. We only ever delete a curated allowlist — never a
# whole profile.
#
# SAFARI: --full needs Full Disk Access granted to /bin/bash (see README).
# Light mode only touches Safari's cache and usually works without it.
#
# Author:  Kris Armstrong <kris.armstrong@icloud.com>
# License: Apache-2.0 (SPDX-License-Identifier: Apache-2.0) — see LICENSE
# Repo:    ~/Developer/mac-cache-cleanup/clear-browsers
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

MODE="light"
DRY_RUN=0
ONLY="" # empty = all installed browsers
while [ $# -gt 0 ]; do
  case "$1" in
    --full) MODE="full" ;;
    --light) MODE="light" ;;
    --dry-run | -n) DRY_RUN=1 ;;
    --only)
      [ $# -ge 2 ] || {
        echo "clear-browsers.sh: --only needs a list (chrome,edge,safari)" >&2
        exit 1
      }
      ONLY="$2"
      shift
      ;;
    --only=*) ONLY="${1#*=}" ;;
    *)
      echo "clear-browsers.sh: unknown argument: $1" >&2
      echo "usage: clear-browsers.sh [--full] [--only chrome,edge,safari] [--dry-run]" >&2
      exit 1
      ;;
  esac
  shift
done

# Normalize ONLY to a space-padded, lowercase set for membership tests, and
# validate the names so a typo (e.g. "chorme") fails loudly instead of silently
# cleaning nothing.
ONLY="$(printf '%s' "$ONLY" | tr 'A-Z,' 'a-z ')"
for _name in $ONLY; do
  case "$_name" in
    chrome | edge | safari) ;;
    *)
      echo "clear-browsers.sh: --only: unknown browser '$_name' (use chrome,edge,safari)" >&2
      exit 1
      ;;
  esac
done

# want <browser>: true if this browser should be acted on (no --only = all).
want() {
  [ -z "${ONLY// /}" ] && return 0
  case " $ONLY " in
    *" $1 "*) return 0 ;;
    *) return 1 ;;
  esac
}

log() { printf '%s  %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" >>"$LOG"; }

# Delete a path if it exists; log the outcome. In --dry-run, report the path
# and its size but delete nothing. Safe under `set -u`.
nuke() {
  local path="$1"
  [ -e "$path" ] || return 0
  if [ "$DRY_RUN" -eq 1 ]; then
    local size
    size="$(du -sh "$path" 2>/dev/null | cut -f1)"
    log "  would delete: ${path/#$HOME_DIR/~} (${size:-?})"
    return 0
  fi
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

# --- Chromium-family cleanup (Chrome / Edge share this layout) ---------------
# $1 = browser support dir, $2 = top-level cache dir, $3 = label
wipe_chromium() {
  local support="$1" topcache="$2" label="$3"
  if [ ! -d "$support" ]; then
    log "$label: no profile dir ($support) — skipping"
    return 0
  fi

  # Top-level (non-profile) cache — pure cache, cleared in both modes.
  nuke "$topcache"

  # Cache/service-worker items: cleared in BOTH modes (no login impact).
  local cache_relpaths=(
    "Cache" "Code Cache" "GPUCache" "DawnCache" "GrShaderCache" "ShaderCache"
    "Service Worker" "Session Storage"
  )
  # Login/identity/history items: cleared ONLY in --full mode.
  local full_relpaths=(
    "IndexedDB" "Local Storage"
    "Network/Cookies" "Network/Cookies-journal"
    "Cookies" "Cookies-journal"
    "History" "History-journal" "History-wal" "History-shm"
    "Top Sites" "Top Sites-journal"
    "Visited Links"
  )
  local relpaths=("${cache_relpaths[@]}")
  [ "$MODE" = "full" ] && relpaths+=("${full_relpaths[@]}")

  # Default + numbered + Guest profiles.
  shopt -s nullglob
  local profiles=("$support/Default" "$support/Profile "* "$support/Guest Profile" "$support/System Profile")
  shopt -u nullglob

  local p rel
  for p in "${profiles[@]}"; do
    [ -d "$p" ] || continue
    log "$label: cleaning profile ${p##*/}"
    for rel in "${relpaths[@]}"; do
      nuke "$p/$rel"
    done
  done
  log "$label: done"
}

# --- Safari cleanup ----------------------------------------------------------
# Light mode clears only the cache. --full also wipes history, site storage,
# and cookies (and needs Full Disk Access for those container paths).
wipe_safari() {
  local container="$HOME_DIR/Library/Containers/com.apple.Safari/Data/Library"
  if [ ! -d "$HOME_DIR/Library/Safari" ] && [ ! -d "$container" ]; then
    log "Safari: not present — skipping"
    return 0
  fi

  # Cache (both modes).
  log "Safari: clearing cache"
  local sub
  shopt -s dotglob nullglob
  for sub in "$container/Caches/"*; do
    nuke "$sub"
  done
  shopt -u dotglob nullglob

  if [ "$MODE" = "full" ]; then
    log "Safari: wiping history, site storage, and cookies (--full)"
    nuke "$HOME_DIR/Library/Safari/History.db"
    nuke "$HOME_DIR/Library/Safari/History.db-wal"
    nuke "$HOME_DIR/Library/Safari/History.db-shm"
    nuke "$HOME_DIR/Library/Safari/History.db-lock"
    nuke "$HOME_DIR/Library/Safari/LocalStorage"
    nuke "$HOME_DIR/Library/Safari/Databases"
    shopt -s dotglob nullglob
    for sub in "$container/WebKit/"*; do
      nuke "$sub"
    done
    shopt -u dotglob nullglob
    nuke "$container/Cookies/Cookies.binarycookies"
  fi

  log "Safari: done (if entries say 'permission', grant Full Disk Access — see README)"
}

# --- Run ---------------------------------------------------------------------
main() {
  if [ "$DRY_RUN" -eq 1 ]; then
    log "=== DRY RUN: browser cleanup (mode=$MODE) — nothing will be deleted ==="
  else
    log "=== Starting browser cleanup (mode=$MODE) ==="
  fi

  # In a real run, quit browsers first so their files are unlocked. In a dry
  # run we leave everything open and just report. Only touch selected browsers.
  local chrome_run="" edge_run="" safari_run=""
  if [ "$DRY_RUN" -eq 0 ]; then
    want chrome && chrome_run="$(quit_app 'Google Chrome' 'Google Chrome')"
    want edge && edge_run="$(quit_app 'Microsoft Edge' 'Microsoft Edge')"
    want safari && safari_run="$(quit_app 'Safari' 'Safari')"
  fi

  if want chrome; then
    wipe_chromium "$HOME_DIR/Library/Application Support/Google/Chrome" \
      "$HOME_DIR/Library/Caches/Google/Chrome" "Chrome"
  fi
  if want edge; then
    wipe_chromium "$HOME_DIR/Library/Application Support/Microsoft Edge" \
      "$HOME_DIR/Library/Caches/Microsoft Edge" "Edge"
  fi
  want safari && wipe_safari

  # Reopen only the browsers that were running before the cleanup.
  if [ "$DRY_RUN" -eq 0 ]; then
    [ -n "$chrome_run" ] && relaunch "Google Chrome"
    [ -n "$edge_run" ] && relaunch "Microsoft Edge"
    [ -n "$safari_run" ] && relaunch "Safari"
  fi

  log "=== Browser cleanup complete (mode=$MODE) ==="
}

# Only run when executed directly, not when sourced (so functions are testable).
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
