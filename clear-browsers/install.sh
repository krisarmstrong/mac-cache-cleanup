#!/bin/bash
#
# install.sh — install (or update) the daily browser cleanup.
# Quits the selected browsers, clears stale cache (and, with --full, also
# cookies + history), reopens whichever were running. Daily at a time you
# choose (default 06:00). Idempotent.
#
#   ./install.sh                       # light cleanup, all browsers (prompts for time)
#   ./install.sh --full                # full wipe: also clear cookies + history (logs you out)
#   ./install.sh --only chrome,edge    # only these browsers (default: all installed)
#   ./install.sh --time 02:30          # run daily at 2:30am
#   sudo ./install.sh --all-users      # install for EVERY user (each in their own session)
#   ./install.sh uninstall             # remove this user's job + installed script
#
# Default mode is "light" — you stay logged in. --full also wipes cookies +
# history; its Safari paths need Full Disk Access granted to /bin/bash (README).
#
# Author:  Kris Armstrong <kris.armstrong@icloud.com>
# License: Apache-2.0 (SPDX-License-Identifier: Apache-2.0) — see LICENSE
#
set -euo pipefail

# ---- Config -----------------------------------------------------------------
# LABEL is the launchd job id (Apple reverse-DNS namespace, NOT a username —
# it's the same string for every user; the job still runs as whoever it's
# loaded for because all paths derive from that user's $HOME at runtime).
LABEL="local.clearbrowsers"
OLD_LABEL="com.krisarmstrong.clearbrowsers" # legacy id — cleaned up on (re)install
SCRIPT="clear-browsers.sh"
DEFAULT_HOUR=6
DEFAULT_MINUTE=0
# -----------------------------------------------------------------------------

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_SCRIPT="$REPO_DIR/$SCRIPT"

usage() {
  sed -n '3,16p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

# ---- Parse args -------------------------------------------------------------
ALL_USERS=0
ACTION="install"
HOUR=""
MINUTE=""
FULL=0  # --full bakes a full wipe into the scheduled job (default: light)
ONLY="" # --only restricts the scheduled job to these browsers

while [ $# -gt 0 ]; do
  case "$1" in
    --all-users) ALL_USERS=1 ;;
    uninstall | --uninstall) ACTION="uninstall" ;;
    --full) FULL=1 ;;
    --only)
      [ $# -ge 2 ] || {
        echo "ERROR: --only needs a list (chrome,edge,safari)" >&2
        exit 1
      }
      ONLY="$2"
      shift
      ;;
    --only=*) ONLY="${1#*=}" ;;
    --time)
      [ $# -ge 2 ] || {
        echo "ERROR: --time needs HH:MM" >&2
        exit 1
      }
      HOUR="${2%%:*}"
      MINUTE="${2##*:}"
      shift
      ;;
    --time=*)
      t="${1#*=}"
      HOUR="${t%%:*}"
      MINUTE="${t##*:}"
      ;;
    -h | --help) usage 0 ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      usage 1
      ;;
  esac
  shift
done

# Build the extra ProgramArguments the scheduled job passes to the cleaner.
SCRIPT_ARGS=()
[ "$FULL" -eq 1 ] && SCRIPT_ARGS+=(--full)
[ -n "$ONLY" ] && SCRIPT_ARGS+=(--only "$ONLY")

# ---- Resolve install scope (paths + launchd domain) -------------------------
if [ "$ALL_USERS" -eq 1 ]; then
  [ "$(id -u)" -eq 0 ] || {
    echo "ERROR: --all-users requires sudo (writes /Library/LaunchAgents)." >&2
    exit 1
  }
  AGENTS_DIR="/Library/LaunchAgents"
  SCRIPTS_DIR="/Library/Scripts"
  TARGET_UID="${SUDO_UID:-}"
else
  [ "$(id -u)" -ne 0 ] || {
    echo "ERROR: run WITHOUT sudo for a single-user install (use --all-users for a system-wide one)." >&2
    exit 1
  }
  AGENTS_DIR="$HOME/Library/LaunchAgents"
  SCRIPTS_DIR="$HOME/Library/Scripts"
  TARGET_UID="$(id -u)"
fi

DEST_SCRIPT="$SCRIPTS_DIR/$SCRIPT"
PLIST="$AGENTS_DIR/$LABEL.plist"
OLD_PLIST="$AGENTS_DIR/$OLD_LABEL.plist"

# Unload a label from the console user's GUI domain if we can reach it.
unload() {
  local label="$1"
  [ -n "$TARGET_UID" ] || return 0
  launchctl bootout "gui/$TARGET_UID/$label" 2>/dev/null || true
}

# ---- Uninstall --------------------------------------------------------------
if [ "$ACTION" = "uninstall" ]; then
  unload "$LABEL"
  unload "$OLD_LABEL"
  rm -f "$PLIST" "$OLD_PLIST" "$DEST_SCRIPT"
  echo "Uninstalled $LABEL (logs left intact)."
  exit 0
fi

# ---- Schedule (flag, else interactive prompt, else default) -----------------
if [ -z "$HOUR" ]; then
  if [ -t 0 ]; then
    printf 'Run daily at what time? [HH:MM, default %02d:%02d] ' "$DEFAULT_HOUR" "$DEFAULT_MINUTE"
    read -r reply || reply=""
    if [ -n "$reply" ]; then
      HOUR="${reply%%:*}"
      MINUTE="${reply##*:}"
    fi
  fi
fi
HOUR="${HOUR:-$DEFAULT_HOUR}"
MINUTE="${MINUTE:-$DEFAULT_MINUTE}"
HOUR=$((10#$HOUR))
MINUTE=$((10#$MINUTE))
{ [ "$HOUR" -ge 0 ] && [ "$HOUR" -le 23 ] && [ "$MINUTE" -ge 0 ] && [ "$MINUTE" -le 59 ]; } \
  || {
    echo "ERROR: time must be 00:00–23:59" >&2
    exit 1
  }

# ---- Install ----------------------------------------------------------------
[ -f "$SRC_SCRIPT" ] || {
  echo "ERROR: $SRC_SCRIPT not found" >&2
  exit 1
}
mkdir -p "$SCRIPTS_DIR" "$AGENTS_DIR"

echo "Installing script → $DEST_SCRIPT"
cp "$SRC_SCRIPT" "$DEST_SCRIPT"
chmod 755 "$DEST_SCRIPT"

if [ "$ALL_USERS" -eq 1 ]; then
  LOG_KEYS=""
else
  LOGS_DIR="$HOME/Library/Logs"
  mkdir -p "$LOGS_DIR"
  LOG_KEYS="    <key>StandardOutPath</key>
    <string>$LOGS_DIR/clear-browsers.out.log</string>
    <key>StandardErrorPath</key>
    <string>$LOGS_DIR/clear-browsers.err.log</string>"
fi

# Render any baked cleaner args (--full / --only LIST) as <string> entries.
# Length-guarded for bash 3.2 (macOS), where expanding an empty array under
# `set -u` would abort.
ARG_STRINGS=""
if [ "${#SCRIPT_ARGS[@]}" -gt 0 ]; then
  for a in "${SCRIPT_ARGS[@]}"; do
    ARG_STRINGS+="
        <string>$a</string>"
  done
fi

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
        <string>$DEST_SCRIPT</string>$ARG_STRINGS
    </array>
    <!-- Daily at $HOUR:$(printf '%02d' "$MINUTE"). If the Mac is off/asleep then,
         launchd runs the missed job once after it next boots/wakes. -->
    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key><integer>$HOUR</integer>
        <key>Minute</key><integer>$MINUTE</integer>
    </dict>
$LOG_KEYS
</dict>
</plist>
PLIST_EOF

if [ "$ALL_USERS" -eq 1 ]; then
  chown root:wheel "$PLIST"
  chmod 644 "$PLIST"
fi

plutil -lint "$PLIST" >/dev/null

unload "$OLD_LABEL"
rm -f "$OLD_PLIST"
unload "$LABEL"
if [ -n "$TARGET_UID" ]; then
  launchctl bootstrap "gui/$TARGET_UID" "$PLIST" 2>/dev/null \
    || echo "Note: could not load into gui/$TARGET_UID now — it will load at next login."
fi

echo
SCHED="$(printf '%02d:%02d' "$HOUR" "$MINUTE")"
MODE_DESC="light (stay logged in)"
[ "$FULL" -eq 1 ] && MODE_DESC="FULL wipe (clears cookies + history)"
if [ "$ALL_USERS" -eq 1 ]; then
  echo "Installed system-wide (all users), scheduled daily at $SCHED."
  echo "  It runs for each user in their own session; new logins pick it up automatically."
else
  echo "Installed for $(id -un), scheduled daily at $SCHED."
fi
echo "  Mode:       $MODE_DESC"
echo "  Browsers:   ${ONLY:-all installed}"
if [ -n "$TARGET_UID" ]; then
  echo "  Run now:    launchctl kickstart -k gui/$TARGET_UID/$LABEL"
fi
echo "  Preview:    ~/Library/Scripts/clear-browsers.sh --dry-run"
echo "  Watch log:  tail -f ~/Library/Logs/clear-browsers.log"
if [ "$ALL_USERS" -eq 1 ]; then
  echo "  Uninstall:  sudo $REPO_DIR/install.sh --all-users uninstall"
else
  echo "  Uninstall:  $REPO_DIR/install.sh uninstall"
fi
if [ "$FULL" -eq 1 ]; then
  echo
  echo "REMINDER: --full needs Full Disk Access for /bin/bash for the Safari wipe (README)."
fi
