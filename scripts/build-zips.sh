#!/bin/bash
#
# build-zips.sh — (re)build the per-package distribution archives in dist/.
# Each package is self-contained (script + installer + README + LICENSE), so
# each gets its own zip that a user can download, unzip, and ./install.sh.
#
#   ./scripts/build-zips.sh
#
# License: Apache-2.0 (SPDX-License-Identifier: Apache-2.0) — see LICENSE
#
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST="$REPO_DIR/dist"
PACKAGES=(clear-outlook-cache clear-teams-cache clear-browsers)

command -v zip >/dev/null || {
  echo "ERROR: zip not found" >&2
  exit 1
}

mkdir -p "$DIST"

for pkg in "${PACKAGES[@]}"; do
  src="$REPO_DIR/$pkg"
  [ -d "$src" ] || {
    echo "ERROR: missing package dir: $src" >&2
    exit 1
  }
  # Scripts must carry exec bits inside the archive so users can run them
  # straight out of the unzip without a chmod step.
  chmod +x "$src"/*.sh

  out="$DIST/$pkg.zip"
  rm -f "$out"
  # -X strips extra file attributes (uid/gid/extra timestamps) for cleaner,
  # more reproducible archives. Zip from REPO_DIR so the archive contains a
  # top-level "<pkg>/" folder.
  (cd "$REPO_DIR" && zip -rX -q "$out" "$pkg")
  echo "built $(basename "$out") ($(du -h "$out" | cut -f1 | tr -d ' '))"
done

echo "Done → $DIST"
