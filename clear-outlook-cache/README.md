# clear-outlook-cache

Daily macOS maintenance that fixes stale Microsoft **Outlook** web content
(e.g. the embedded **Dynamics App**) by clearing Outlook's cache. Self-contained
— does not depend on any other package. Runs daily at a time you choose
(default **06:00**) via launchd.

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
./install.sh                                  # current user; prompts for the time
```

Paths auto-adapt to whoever runs it (`$HOME` at runtime) — no editing required.

### Choosing the time

The installer asks for a time and defaults to `06:00` (press Enter to accept).
To set it non-interactively, pass `--time`:

```bash
./install.sh --time 02:30      # run daily at 2:30am
```

Re-running `install.sh` with a new time just updates the schedule — it's
idempotent.

### Single user vs. all users

- **Single user (default):** installs to `~/Library/LaunchAgents` and runs only
  for you.
- **All users:** installs to `/Library/LaunchAgents`. launchd loads it into
  **each user's** login session and runs it as that user, against that user's
  own Outlook data and logs:

  ```bash
  sudo ./install.sh --all-users --time 06:00
  ```

  New logins pick it up automatically; currently logged-in users get it loaded
  right away. (A root *daemon* can't be used here — the job needs each user's
  GUI session and per-user Outlook container, which a per-user agent provides.)

If macOS blocks the scripts because they were downloaded:

```bash
xattr -dr com.apple.quarantine .
```

## Commands

```bash
launchctl kickstart -k gui/$(id -u)/local.clearoutlookcache   # run now
~/Library/Scripts/clear-outlook-cache.sh                      # run directly
tail -f ~/Library/Logs/clear-outlook-cache.log               # watch log
./install.sh uninstall                                        # remove (single user)
sudo ./install.sh --all-users uninstall                       # remove (all users)
```

## Requirements

macOS with Microsoft Outlook installed. Uses `/bin/bash` (preinstalled) — no
dependencies.

## License

Apache-2.0 — see [LICENSE](LICENSE).
