# clear-browsers

Daily macOS cleanup for **Google Chrome, Microsoft Edge, and Safari** that fixes
stale web content, then reopens only the browsers that were running.
Self-contained — does not depend on any other package. Runs daily at a time you
choose (default **06:00**) via launchd.

Two modes:

- **Light (default)** — clears caches + service workers only. You **stay logged
  in**; cookies, local storage, and history are kept. Fixes stale content
  without a daily re-login.
- **Full wipe (`--full`)** — also erases cookies, site storage, and history, so
  you're **logged out of every site**. The original behavior, now opt-in.

## What it does

1. Quits each selected browser that is running.
2. **Light:** deletes per profile (`Default`, `Profile N`, …) the cache, code
   cache, GPU/shader caches, service workers, and session storage. Safari: cache
   only.
   **`--full`:** additionally deletes cookies, IndexedDB, local storage,
   history, top sites, and visited links (Safari: history, WebKit storage, and
   cookies too).
3. **Reopens only the browsers that were running** before the cleanup.

- **Preserved in both modes:** bookmarks, saved passwords, extensions, settings,
  autofill. The script deletes a curated allowlist — never the whole profile.
- **`--full` consequences:** you are **logged out of every site** and **history
  is erased** on each run. If browser **Sync** is on, those deletions may
  propagate to your other devices.

## Modes & options

```bash
./install.sh                       # light cleanup (stay logged in) — the default
./install.sh --full                # full wipe (also clears cookies + history)
./install.sh --only chrome,edge    # only these browsers (default: all installed)
```

- `--only` takes any of `chrome`, `edge`, `safari`. Browsers that aren't
  installed are skipped automatically, so `--only` is just for *excluding*
  installed browsers you don't want touched.
- Flags can be combined (`--full --only chrome`) and re-running `install.sh`
  updates the scheduled job in place.

### Preview first with `--dry-run`

To see exactly what *would* be deleted (with sizes) without deleting anything:

```bash
~/Library/Scripts/clear-browsers.sh --dry-run          # preview light cleanup
~/Library/Scripts/clear-browsers.sh --full --dry-run   # preview a full wipe
```

It deletes nothing and doesn't quit/relaunch your browsers — output goes to
`~/Library/Logs/clear-browsers.log`.

## ⚠️ Full Disk Access — only needed for `--full` + Safari

The **light** default doesn't need any special permission. **`--full`** wipes
Safari's macOS-protected data via `/bin/bash`, so grant it Full Disk Access or
the Safari steps log `FAILED (permission?)`:

1. System Settings → **Privacy & Security** → **Full Disk Access**.
2. Click **+**, press **⌘⇧G**, enter `/bin/bash`, add it, toggle it **on**.
3. Chrome and Edge never need this — only Safari's `--full` wipe does.

Granting FDA to `/bin/bash` is broad (any bash script gets it). If you'd rather
not, just use the light default (or `--only chrome,edge`).

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
  and runs it as that user, against their own browser data. (If you use
  `--full`, each user must grant Full Disk Access for the Safari wipe — it's a
  per-user setting.)

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
