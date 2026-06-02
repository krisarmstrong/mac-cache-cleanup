# mac-cache-cleanup

[![CI](https://github.com/krisarmstrong/mac-cache-cleanup/actions/workflows/ci.yml/badge.svg)](https://github.com/krisarmstrong/mac-cache-cleanup/actions/workflows/ci.yml)
[![License: Apache 2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)
[![Platform: macOS](https://img.shields.io/badge/platform-macOS-lightgrey.svg)](https://www.apple.com/macos/)
[![Shell: bash](https://img.shields.io/badge/shell-bash-4EAA25.svg)](#requirements)
[![ShellCheck](https://img.shields.io/badge/linted-shellcheck-brightgreen.svg)](https://www.shellcheck.net/)
[![Release](https://img.shields.io/github/v/release/krisarmstrong/mac-cache-cleanup?sort=semver)](https://github.com/krisarmstrong/mac-cache-cleanup/releases)

A small collection of **independent** macOS maintenance tools that quit a
Microsoft app, clear its stale cache, and relaunch it on a daily schedule
(launchd, default 06:00). Built to fix stale web content — most notably the
**Dynamics App embedded in Outlook**, and the same class of flaky-UI issues in
Teams.

Each tool is **self-contained**: its own script, its own installer, its own
README, and its own launchd job. None depends on the others — install, zip,
share, or remove any single one on its own.

## Packages

| Package | What it clears | Logs you out? | launchd label |
|---|---|---|---|
| [`clear-outlook-cache`](clear-outlook-cache/) | Outlook `Caches` + `WebKit` | No | `local.clearoutlookcache` |
| [`clear-teams-cache`](clear-teams-cache/) | Teams web cache (keeps login + backgrounds) | No | `local.clearteamscache` |
| [`clear-browsers`](clear-browsers/) | Chrome/Edge/Safari caches (cookies + history only with `--full`) | No¹ | `local.clearbrowsers` |

> ¹ `clear-browsers` defaults to a **light** cleanup that keeps you logged in
> (caches only). Its opt-in `--full` mode wipes cookies + history (logs you out
> of every site) and needs Full Disk Access for Safari — read its README before
> using `--full`. All three tools are non-destructive to your logins by default.

## Install

Each package independently (the installer prompts for a run time, default
`06:00`):

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

No editing required — every installer derives paths from `$HOME` at runtime, so
it works for whoever runs it.

### Set the time

Each installer defaults to `06:00` and accepts a `--time HH:MM` flag (or prompts
when run interactively):

```bash
./install.sh --time 02:30          # this package, daily at 2:30am
./install-all.sh --time 02:30      # all three at 2:30am
```

### One user vs. all users

By default a tool installs into `~/Library/LaunchAgents` and runs **only for
you**. To schedule it for **every** user on the Mac, install system-wide with
`sudo` — launchd then loads the job into each user's login session and runs it
as that user, against their own app data:

```bash
sudo ./install.sh --all-users               # one package, all users
sudo ./install-all.sh --all-users           # all packages, all users
sudo ./install-all.sh --all-users uninstall # remove the all-users install
```

### Browser modes (clear-browsers only)

The browser tool defaults to a **light** cleanup (caches only — you stay logged
in). Two optional flags, forwarded through `install-all.sh` too; see the
[clear-browsers README](clear-browsers/) for details:

```bash
./install.sh --full                # also wipe cookies + history (logs you out)
./install.sh --only chrome,edge    # only these browsers (default: all installed)
~/Library/Scripts/clear-browsers.sh --dry-run   # preview deletions, delete nothing
```

If macOS blocks downloaded scripts ("cannot be opened"), clear quarantine once
in the unzipped folder: `xattr -dr com.apple.quarantine .`

## Schedule & missed runs

Each job uses launchd `StartCalendarInterval` at the time you chose (default
06:00). If the Mac is off or asleep then, launchd runs the missed job once after
it next boots/wakes and you log in.

## Requirements

macOS. Uses `/bin/bash` (preinstalled) — no dependencies to install.

> **zsh users:** nothing special needed. Your interactive shell doesn't matter —
> the scripts run under `/bin/bash` via their shebang, and the launchd jobs call
> `/bin/bash` explicitly. They're written to work on Apple's stock bash 3.2.
> (Just don't run them manually with `zsh`/`sh` — use `./install.sh` or the
> installed script directly so the shebang picks bash.)

## Issues & contributing

- **Bug or feature idea?** Open an [issue](https://github.com/krisarmstrong/mac-cache-cleanup/issues/new/choose)
  (bug report and feature request templates provided).
- **"How do I…" question?** Use [Discussions](https://github.com/krisarmstrong/mac-cache-cleanup/discussions).
- **Security issue?** See [SECURITY.md](SECURITY.md) — report privately, not as a public issue.
- **Pull requests** are welcome; CI runs ShellCheck + shfmt and a macOS
  install/uninstall smoke test, so run those locally first (see the PR
  checklist).

## License

Apache-2.0 — see [LICENSE](LICENSE). Copyright (c) 2026 Kris Armstrong.
