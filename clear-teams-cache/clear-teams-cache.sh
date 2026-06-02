#!/bin/bash
#
# clear-teams-cache.sh
# Quits Microsoft Teams (new Teams / "MSTeams"), clears its stale web cache,
# and relaunches it. Fixes the same class of stale-UI problems as the Outlook
# cleanup (blank channels, stuck loading, old content).
#
# Like the Outlook script, this clears CACHE + web content only and PRESERVES
# cookies / login / Local Storage — so Teams stays signed in (no daily re-auth).
#
# Direct delete (rm) — nothing goes through the Trash.
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

TEAMS_CONTAINER_ROOT="$HOME_DIR/Library/Containers/com.microsoft.teams2"
CONTAINER="$TEAMS_CONTAINER_ROOT/Data/Library"
EBWEBVIEW="$CONTAINER/Application Support/Microsoft/MSTeams/EBWebView"
# PROTECTED — custom video backgrounds (uploaded images). NEVER delete this.
# It is a sibling of EBWebView, outside every path this script clears.
BACKGROUNDS="$CONTAINER/Application Support/Microsoft/MSTeams/Backgrounds"
LOG="$HOME_DIR/Library/Logs/clear-teams-cache.log"
# -----------------------------------------------------------------------------

log() { printf '%s  %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" >>"$LOG"; }

# Delete every entry inside a directory (contents, not the dir itself).
clear_contents() {
  local dir="$1" label="$2" count=0
  case "$dir" in
    "$BACKGROUNDS"|"$BACKGROUNDS"/*)
      log "$label: REFUSED to clear protected backgrounds path: $dir"
      return 0 ;;
  esac
  if [ ! -d "$dir" ]; then
    log "$label: folder absent — skipping ($dir)"
    return 0
  fi
  shopt -s dotglob nullglob
  local item
  for item in "$dir"/*; do
    if rm -rf -- "$item" 2>>"$LOG"; then
      count=$((count + 1))
    else
      log "  failed to delete: $item"
    fi
  done
  shopt -u dotglob nullglob
  log "$label: deleted $count item(s)"
}

# Delete a single path if present. Refuses to delete anything inside the
# protected Backgrounds folder — a hard safety net against future edits.
nuke() {
  local path="$1" label="$2"
  case "$path" in
    "$BACKGROUNDS"|"$BACKGROUNDS"/*)
      log "$label: REFUSED to delete protected backgrounds path: $path"
      return 0 ;;
  esac
  [ -e "$path" ] || return 0
  if rm -rf -- "$path" 2>>"$LOG"; then
    log "$label: deleted ${path##*/}"
  else
    log "$label: FAILED ${path##*/}"
  fi
}

main() {
  log "=== Starting Teams cache cleanup ==="

  if [ ! -d "$TEAMS_CONTAINER_ROOT" ]; then
    log "Teams (new) not installed — nothing to do"
    return 0
  fi

  local was_running=""
  if pgrep -x "MSTeams" >/dev/null 2>&1; then
    was_running="yes"
    log "Teams running — requesting graceful quit"
    osascript -e 'tell application "Microsoft Teams" to quit' >/dev/null 2>&1
    for _ in $(seq 1 20); do
      pgrep -x "MSTeams" >/dev/null 2>&1 || break
      sleep 1
    done
    if pgrep -x "MSTeams" >/dev/null 2>&1; then
      log "Still running — force quitting"
      pkill -x "MSTeams" 2>/dev/null
      sleep 2
      pkill -9 -x "MSTeams" 2>/dev/null
      sleep 1
    fi
    log "Teams is closed"
  else
    log "Teams was not running"
  fi

  # Container-level cache + web content (regenerable).
  clear_contents "$CONTAINER/Caches" "Caches"
  clear_contents "$CONTAINER/WebKit" "WebKit"

  # Edge-WebView (the engine new Teams renders in). Clear caches, GPU/shader
  # caches, service workers and transient per-session storage across EVERY
  # profile (e.g. Default, WV2Profile_tfw). KEEP Cookies, Local Storage,
  # IndexedDB, WebStorage, SharedStorage and Local State so the Teams session
  # and settings survive — no daily re-login.
  if [ -d "$EBWEBVIEW" ]; then
    # Top-level (non-profile) caches.
    local t
    for t in GPUCache ShaderCache GrShaderCache GraphiteDawnCache \
             component_crx_cache extensions_crx_cache; do
      nuke "$EBWEBVIEW/$t" "EBWebView"
    done

    # Cache-like subdirs to clear inside any profile dir. Anything not listed
    # (Cookies, Local Storage, IndexedDB, WebStorage, …) is left untouched.
    local clearable=(
      "Cache" "Code Cache" "GPUCache" "DawnCache" "DawnGraphiteCache"
      "DawnWebGPUCache" "Service Worker" "blob_storage" "Session Storage"
      "optimization_guide_hint_cache_store" "AutofillAiModelCache"
    )
    shopt -s nullglob
    local prof sub
    for prof in "$EBWEBVIEW"/*; do
      [ -d "$prof" ] || continue
      # Only descend into things that look like a profile (have a Cookies or
      # storage file), so we don't churn unrelated engine dirs.
      [ -e "$prof/Cookies" ] || [ -d "$prof/Local Storage" ] || [ -d "$prof/Service Worker" ] || continue
      for sub in "${clearable[@]}"; do
        nuke "$prof/$sub" "EBWebView/${prof##*/}"
      done
    done
    shopt -u nullglob
  else
    log "EBWebView: absent — skipping"
  fi

  # Safety verification — custom backgrounds must still be there.
  if [ -d "$BACKGROUNDS/Uploads" ]; then
    log "Backgrounds intact: $(ls -1 "$BACKGROUNDS/Uploads" 2>/dev/null | wc -l | tr -d ' ') file(s) in Uploads"
  elif [ -d "$BACKGROUNDS" ]; then
    log "Backgrounds folder intact (no Uploads subfolder)"
  else
    log "WARNING: Backgrounds folder is missing after run — this should NOT happen"
  fi

  # Relaunch only if it was running.
  if [ -n "$was_running" ]; then
    log "Relaunching Teams"
    open -a "Microsoft Teams" 2>>"$LOG" || log "Failed to relaunch Teams"
  else
    log "Teams was not running — leaving it closed"
  fi

  log "=== Teams cleanup complete ==="
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
