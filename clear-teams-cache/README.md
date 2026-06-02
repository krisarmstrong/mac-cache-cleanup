# clear-teams-cache

Daily macOS maintenance that fixes stale **Microsoft Teams** (new Teams /
`MSTeams`) web content — blank channels, stuck loading, old content. Keeps you
**logged in** and **preserves custom video backgrounds**. Self-contained — does
not depend on any other package. Runs daily at **06:00** via launchd.

## What it does

1. Quits Teams (if running), clears stale web cache, relaunches it **only if it
   was running**.
2. Clears: container `Caches` + `WebKit`, and per Edge-WebView profile
   (`Default`, `WV2Profile_tfw`): `Cache`, `Code Cache`, `GPUCache`, Dawn/shader
   caches, `Service Worker`, `blob_storage`, `Session Storage`, hint caches.

### Preserved (never deleted)
- **Login** — cookies, `Local Storage`, `IndexedDB`, `WebStorage` (no daily re-auth).
- **Custom video backgrounds** (`.../MSTeams/Backgrounds/`) — protected by an
  explicit guard that refuses to delete anything under that folder, plus a
  post-run check that logs the file count.

## Install

```bash
chmod +x install.sh clear-teams-cache.sh   # in case the download dropped exec bits
./install.sh
```

No editing required — paths auto-adapt to your account (`HOME_DIR="${HOME}"` at
the top of each file; override it to target a different account).

If macOS blocks the scripts because they were downloaded:

```bash
xattr -dr com.apple.quarantine .
```

## Commands

```bash
launchctl kickstart -k gui/$(id -u)/com.krisarmstrong.clearteamscache  # run now
~/Library/Scripts/clear-teams-cache.sh                                 # run directly
tail -f ~/Library/Logs/clear-teams-cache.log                           # watch log
./install.sh uninstall                                                 # remove
```

## Requirements

macOS with **new** Microsoft Teams installed (`com.microsoft.teams2`). Uses
`/bin/bash` (preinstalled) — no dependencies. (Classic Teams is not targeted.)

## License

Apache-2.0 — see [LICENSE](LICENSE).
