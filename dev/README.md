# Dev workflow (scottconnor fork)

Notes for working on my fork of [billyfw/ha-frame-art-manager](https://github.com/billyfw/ha-frame-art-manager).
Everything in `dev/` is mine and must never go upstream (see [Sending a PR upstream](#sending-a-pr-upstream)).

## Where things live

| What | Where |
|---|---|
| Code, edited on the Mac | `frame-art-manager/` on my network share, mounted on the Mac |
| Same checkout on the dev server | `~/frame-art-manager` (`ssh mintvm`) |
| Production add-on on HA | **Frame Art Manager** from billyfw's repo, port 8099 |
| Dev add-on on HA | **Frame Art Manager (DEV)** (`local_frame_art_manager_dev`), port 8098 |
| Old known-good build | tag `v1.25.12`: billyfw's 1.25.11 + my SSH sync fixes, ran May–Oct 2026 |

Remotes in the checkout: `origin` = my fork, `upstream` = billyfw.

**Run git on the dev server, not the Mac.** Git over the network share is slow. Edit files
on the Mac, then:

```bash
ssh mintvm
cd ~/frame-art-manager
```

## Testing a change on Home Assistant

From the repo folder, on the Mac or on the dev server (`~/frame-art-manager`), no commit
needed:

```bash
dev/deploy-ha-dev.sh
```

It sends the files as they are in that folder, so check out the branch you want to test
first.

It copies `frame_art_manager/` to HA as the DEV add-on and rebuilds it. Then start it,
or open it, from **Settings > Add-ons > Frame Art Manager (DEV)**. The script only
renames the *copy* it sends (name, slug, port 8098, library path); the repo's
`config.yaml` stays identical to upstream.

The DEV add-on:
- uses its own library, `/config/www/frame_art_dev`, never the real one
- has **no `ssh_private_key`**, so it cannot push into the real art library on GitHub.
  Keep it that way.
- has boot set to manual, so it only runs when I start it

For quick UI work, run just the Node app on the dev server:
`cd ~/frame-art-manager/frame_art_manager/app && npm install && npm run dev`, with `.env`
pointing `FRAME_ART_PATH` at a scratch library (see `app/.env.example`). HA-specific
features still need the DEV add-on.

## Branches

| Branch | Contents | Goes to |
|---|---|---|
| `main` | `upstream/main` + my dev commit(s) (`dev/`, `._*` ignore) | my fork only |
| `feat/<name>` | branched from `main`, so the deploy script is there | my fork |
| `pr/<name>` | the feature commits replayed onto `upstream/main`, without `dev/` | PR to billyfw |

### Starting a feature

```bash
git switch main
git switch -c feat/my-thing
# edit on the Mac, dev/deploy-ha-dev.sh, test, commit as I go
```

### Sending a PR upstream

Copy just the feature commits onto billyfw's `main`, leaving my dev commit behind:

```bash
git fetch upstream
git switch -c pr/my-thing feat/my-thing
git rebase --onto upstream/main main pr/my-thing
git log --oneline upstream/main..pr/my-thing   # check: only feature commits, no "dev:" commit
git push -u origin pr/my-thing
```

Open the PR from `scottconnor:pr/my-thing` into `billyfw:main`.
**Never open a PR from `main`**: it carries the `dev/` commit.

### Keeping up with billyfw

When upstream releases something:

```bash
git fetch upstream
git switch main
git rebase upstream/main
git push --force-with-lease origin main
```

Force-pushing my own `main` is expected here. My dev commit only touches `dev/` and
`.gitignore`, so it replays cleanly, even if billyfw rewrites history again (that happened in
Oct 2026, which is why the fork and upstream once shared no commits).

## This repo is public

- Commits here use my GitHub noreply address (set in this checkout's git config).
- Before pushing, run `python3 scripts/check_no_pii.py`. Add private names to look for in
  `~/.config/pii/markers.txt` (one per line, never committed).
- Never push a branch or tag that reaches the pre-Oct-2026 history: it still carries
  details billyfw scrubbed. Base everything on `upstream/main` or upstream's tags.
- Keep home-network specifics (host names, users, IPs) out of commits; they live in
  `~/.ssh/config`.

## One-time setup (already done, for reference)

- **SSH aliases** in `~/.ssh/config`, each with its own key: `ssh mintvm` (dev server) and
  `ssh homeassistant` (HA's Terminal & SSH add-on). The deploy script uses the HA one.
- **HA key on each machine that deploys**: the script reads `~/.ssh/id_ed25519_homeassistant`
  (override with `HA_SSH_KEY`). The Mac and the dev server each have their own key with that
  name, both listed in the Terminal & SSH add-on's `authorized_keys`; set `HA_HOST` /
  `HA_PORT` if the defaults (`homeassistant.local`, 22) don't reach HA from that machine.
- **HA Terminal & SSH add-on**: the deploy key is authorized and its port is mapped. Its boot
  is manual: **after an HA reboot, start it again** or the deploy script can't connect.
- **DEV add-on**: the first time, the script copies files and asks you to install
  **Frame Art Manager (DEV)** from **Settings > Add-ons > Add-on Store > Local add-ons**; after
  that it rebuilds automatically.
- **Network share**: Samba has macOS support on (`vfs objects = catia fruit streams_xattr`,
  `fruit:metadata = stream`, `fruit:resource = stream`), so the Mac stops writing `._*` files.
