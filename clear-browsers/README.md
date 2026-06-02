# clear-browsers

Daily macOS **full wipe** of cache + cookies + site data + history for **Google
Chrome, Microsoft Edge, and Safari**, then reopens only the browsers that were
running. Self-contained — does not depend on any other package. Runs daily at a
time you choose (default **06:00**) via launchd.

## What it does

1. Quits each browser that is running.
2. Deletes, per profile (`Default`, `Profile N`, …): cache, cookies, IndexedDB,
   Local/Session Storage, service workers, history, top sites, visited links.
   Safari: history, cache, WebKit storage, cookies (in its container).
3. **Reopens only the browsers that were running** before the wipe.

- **Preserved:** bookmarks, saved passwords, extensions, settings, autofill.
  The script deletes a curated allowlist — never the whole profile.
- **Consequences:** you are **logged out of every site** and **all history is
  erased** on each run. If browser **Sync** is on, those deletions may
  propagate to your other devices.

## ⚠️ Safari requires Full Disk Access (one-time, manual)

Safari's data is macOS-protected. The scheduled job runs via `/bin/bash`, so
grant it Full Disk Access or the Safari steps log `FAILED (permission?)`:

1. System Settings → **Privacy & Security** → **Full Disk Access**.
2. Click **+**, press **⌘⇧G**, enter `/bin/bash`, add it, toggle it **on**.
3. Chrome and Edge work without this — only Safari needs it.

Granting FDA to `/bin/bash` is broad (any bash script gets it). If you'd rather
not, delete the `wipe_safari` call in `clear-browsers.sh` and clear Safari
manually via Settings → Privacy → Manage Website Data.

## Install

```bash
chmod +x install.sh clear-browsers.sh   # in case the download dropped exec bits
./install.sh                             # current user; prompts for the time
```

Paths auto-adapt to whoever runs it (`$HOME` at runtime) — no editing required.

### Choosing the time

The installer asks for a time and defaults to `06:00` (press Enter to accept).
To set it non-interactively, pass `--time`:

```bash
./install.sh --time 02:30      # run daily at 2:30am
```

### Single user vs. all users

- **Single user (default):** installs to `~/Library/LaunchAgents`, runs only
  for you.
- **All users:** `sudo ./install.sh --all-users` installs to
  `/Library/LaunchAgents`; launchd loads it into **each** user's login session
  and runs it as that user, against their own browser data. (Each user must
  still grant Full Disk Access for the Safari wipe — it's a per-user setting.)

If macOS blocks the scripts because they were downloaded:

```bash
xattr -dr com.apple.quarantine .
```

## Commands

```bash
launchctl kickstart -k gui/$(id -u)/local.clearbrowsers  # run now
~/Library/Scripts/clear-browsers.sh                      # run directly
tail -f ~/Library/Logs/clear-browsers.log                # watch log
./install.sh uninstall                                   # remove (single user)
sudo ./install.sh --all-users uninstall                  # remove (all users)
```

## Requirements

macOS. Targets Chrome, Edge, Safari if present (each is optional). Uses
`/bin/bash` (preinstalled) — no dependencies.

## License

Apache-2.0 — see [LICENSE](LICENSE).
