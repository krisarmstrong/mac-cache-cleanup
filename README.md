# mac-cache-cleanup

[![License: Apache 2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)
[![Platform: macOS](https://img.shields.io/badge/platform-macOS-lightgrey.svg)](https://www.apple.com/macos/)
[![Shell: bash](https://img.shields.io/badge/shell-bash-4EAA25.svg)](#requirements)
[![Release](https://img.shields.io/github/v/release/krisarmstrong/mac-cache-cleanup?sort=semver)](https://github.com/krisarmstrong/mac-cache-cleanup/releases)

A small collection of **independent** macOS maintenance tools that quit a
Microsoft app, clear its stale cache, and relaunch it on a daily schedule
(launchd, 06:00). Built to fix stale web content — most notably the **Dynamics
App embedded in Outlook**, and the same class of flaky-UI issues in Teams.

Each tool is **self-contained**: its own script, its own installer, its own
README, and its own launchd job. None depends on the others — install, zip,
share, or remove any single one on its own.

## Packages

| Package | What it clears | Logs you out? | launchd label |
|---|---|---|---|
| [`clear-outlook-cache`](clear-outlook-cache/) | Outlook `Caches` + `WebKit` | No | `com.krisarmstrong.clearoutlookcache` |
| [`clear-teams-cache`](clear-teams-cache/) | Teams web cache (keeps login + backgrounds) | No | `com.krisarmstrong.clearteamscache` |
| [`clear-browsers`](clear-browsers/) | Chrome/Edge/Safari **full wipe** (cache, cookies, history) | **Yes** | `com.krisarmstrong.clearbrowsers` |

> ⚠️ `clear-browsers` is aggressive by design: it logs you out of every site and
> erases history daily, and (Safari only) needs Full Disk Access. Read its
> README before installing. The Outlook and Teams tools are non-destructive to
> your logins.

## Install

Each package independently:

```bash
cd clear-outlook-cache && ./install.sh     # just Outlook
cd clear-teams-cache   && ./install.sh     # just Teams
cd clear-browsers      && ./install.sh     # just browsers (read its README first)
```

Or all three at once:

```bash
./install-all.sh            # install/update all
./install-all.sh uninstall  # remove all
```

No editing required — every script and installer derives paths from
`HOME_DIR="${HOME}"` (a one-line Config block at the top), so it works for any
user as-is. To target a different account, change that one line.

If macOS blocks downloaded scripts ("cannot be opened"), clear quarantine once
in the unzipped folder: `xattr -dr com.apple.quarantine .`

## Schedule & missed runs

Each job uses launchd `StartCalendarInterval` at 06:00. If the Mac is off or
asleep then, launchd runs the missed job once after it next boots/wakes and you
log in.

## Requirements

macOS. Uses `/bin/bash` (preinstalled) — no dependencies to install.

## License

Apache-2.0 — see [LICENSE](LICENSE). Copyright (c) 2026 Kris Armstrong.
