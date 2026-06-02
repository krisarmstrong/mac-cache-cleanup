# clear-outlook-cache

Daily macOS maintenance that fixes stale Microsoft **Outlook** web content
(e.g. the embedded **Dynamics App**) by clearing Outlook's cache. Self-contained
— does not depend on any other package. Runs daily at **06:00** via launchd.

## What it does

1. Quits Outlook (graceful, then force-quit if it lingers).
2. Deletes the contents of:
   - `~/Library/Containers/com.microsoft.Outlook/Data/Library/Caches/`
   - `~/Library/Containers/com.microsoft.Outlook/Data/Library/Application Support/WebKit/`
3. Relaunches Outlook.

Deletion is direct (`rm`) — nothing goes through the Trash. Safe because Outlook
regenerates this data on next launch.

> After it runs, **test the Dynamics App** in Outlook (that step is manual).

## Install

```bash
chmod +x install.sh clear-outlook-cache.sh   # in case the download dropped exec bits
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
launchctl kickstart -k gui/$(id -u)/com.krisarmstrong.clearoutlookcache  # run now
~/Library/Scripts/clear-outlook-cache.sh                                 # run directly
tail -f ~/Library/Logs/clear-outlook-cache.log                           # watch log
./install.sh uninstall                                                   # remove
```

## Requirements

macOS with Microsoft Outlook installed. Uses `/bin/bash` (preinstalled) — no
dependencies.

## License

Apache-2.0 — see [LICENSE](LICENSE).
