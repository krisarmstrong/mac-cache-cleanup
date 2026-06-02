#!/bin/bash
#
# install-all.sh — convenience wrapper that installs every package in this
# repo by running each package's own install.sh. Each package is independent;
# this just saves you running all three by hand. Any flags are forwarded
# verbatim to each package installer.
#
#   ./install-all.sh                         # install / update all three (prompts for time)
#   ./install-all.sh --time 02:30            # all three, daily at 2:30am
#   sudo ./install-all.sh --all-users        # all three, every user on the Mac
#   ./install-all.sh uninstall               # remove all three
#   sudo ./install-all.sh --all-users uninstall
#
# Author:  Kris Armstrong <kris.armstrong@icloud.com>
# License: Apache-2.0 (SPDX-License-Identifier: Apache-2.0) — see LICENSE
#
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGES=(clear-outlook-cache clear-teams-cache clear-browsers)

# Whatever was passed (uninstall, --time HH:MM, --all-users, …) goes straight
# through to each installer, which owns the argument parsing.
ARGS=("$@")
VERB="install"
for a in "$@"; do [ "$a" = "uninstall" ] && VERB="uninstall"; done

for pkg in "${PACKAGES[@]}"; do
  installer="$REPO_DIR/$pkg/install.sh"
  [ -x "$installer" ] || chmod +x "$installer" 2>/dev/null || true
  echo "════════════════════════════════════════════════════════════"
  echo "  $pkg"
  echo "════════════════════════════════════════════════════════════"
  "$installer" "${ARGS[@]}"
  echo
done

echo "All packages ${VERB}ed."
