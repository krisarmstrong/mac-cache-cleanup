# Security Policy

## Reporting a vulnerability

These tools delete cache and (for `clear-browsers`) cookies/history on a daily
schedule, and `clear-browsers` can be granted Full Disk Access — so a bug here
could destroy more than intended.

If you find a security issue (e.g. a deletion path that could escape its
intended directory, or a privilege/scope problem in the installer), please
**do not open a public issue**. Instead, report it privately via GitHub's
[security advisory form](https://github.com/krisarmstrong/mac-cache-cleanup/security/advisories/new).

Please include the tool, your macOS version, and a minimal reproduction. You'll
get an acknowledgement as soon as possible.

## Scope notes

- The cleaners delete a curated allowlist of cache/web-data paths under the
  current user's `~/Library` — never whole profiles or arbitrary paths.
- Installers run as the invoking user; `--all-users` requires `sudo` and writes
  only to `/Library/LaunchAgents` and `/Library/Scripts`.
- No network access, telemetry, or third-party dependencies — everything uses
  preinstalled macOS tooling (`/bin/bash`, `launchctl`, `osascript`).
