#!/bin/bash
#
# install-all.sh — convenience wrapper that installs every package in this
# repo by running each package's own install.sh. Each package is independent;
# this just saves you running all three by hand. Pass "uninstall" to remove all.
#
#   ./install-all.sh            # install / update all three
#   ./install-all.sh uninstall  # remove all three
#
# Author:  Kris Armstrong <kris.armstrong@icloud.com>
# License: Apache-2.0 (SPDX-License-Identifier: Apache-2.0) — see LICENSE
#
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGES=(clear-outlook-cache clear-teams-cache clear-browsers)
ACTION="${1:-install}"

for pkg in "${PACKAGES[@]}"; do
  installer="$REPO_DIR/$pkg/install.sh"
  if [ ! -x "$installer" ]; then
    chmod +x "$installer" 2>/dev/null || true
  fi
  echo "════════════════════════════════════════════════════════════"
  echo "  $pkg"
  echo "════════════════════════════════════════════════════════════"
  if [ "$ACTION" = "uninstall" ]; then
    "$installer" uninstall
  else
    "$installer"
  fi
  echo
done

echo "All packages ${ACTION}ed."
