#!/usr/bin/env bash
# Push this working tree to Home Assistant as a local "DEV" add-on and rebuild it.
#
# The copy is renamed (slug frame_art_manager_dev, host port 8098, its own library
# path) so it installs beside the production add-on without clashing. Nothing is
# committed or pushed; HA builds straight from the files copied to /local_apps.
#
# Needs the Terminal & SSH add-on running with your public key authorized.
# Override the connection with HA_HOST / HA_PORT / HA_USER / HA_SSH_KEY.
set -euo pipefail

HA_HOST="${HA_HOST:-homeassistant.local}"
HA_PORT="${HA_PORT:-22}"
HA_USER="${HA_USER:-root}"
HA_SSH_KEY="${HA_SSH_KEY:-$HOME/.ssh/id_ed25519_homeassistant}"

DEST=/local_apps/frame_art_manager_dev
SLUG=local_frame_art_manager_dev
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

SSH=(ssh -i "$HA_SSH_KEY" -p "$HA_PORT" -o ConnectTimeout=10 "$HA_USER@$HA_HOST")

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

# node_modules is rebuilt by `npm ci` in the Dockerfile; never ship the local one
rsync -a \
  --exclude node_modules --exclude .env --exclude tmp-test --exclude '._*' --exclude .DS_Store \
  "$ROOT/frame_art_manager/" "$STAGE/"

# Rebrand the copy only; the repo's config.yaml stays identical to upstream
sed -i '' \
  -e 's/^name: .*/name: Frame Art Manager (DEV)/' \
  -e 's/^slug: .*/slug: frame_art_manager_dev/' \
  -e 's/^panel_title: .*/panel_title: Frame Art (DEV)/' \
  -e 's|^  frame_art_path: /config/www/frame_art$|  frame_art_path: /config/www/frame_art_dev|' \
  -e 's|^  8099/tcp: 8099$|  8099/tcp: 8098|' \
  "$STAGE/config.yaml"
grep -q '^slug: frame_art_manager_dev$' "$STAGE/config.yaml"

echo "Copying to $HA_HOST:$DEST ..."
tar -C "$STAGE" -cf - . | "${SSH[@]}" "rm -rf '$DEST' && mkdir -p '$DEST' && tar -C '$DEST' -xf -"

# `ha apps info` succeeds for uninstalled apps too; only an installed one has a version
INSTALLED="$("${SSH[@]}" "ha apps info $SLUG --raw-json | jq -r '.data.version // empty'")"
if [ -n "$INSTALLED" ]; then
  echo "Rebuilding $SLUG ..."
  "${SSH[@]}" "ha apps rebuild $SLUG"
  echo "Done. Start or open it from Settings > Add-ons > Frame Art Manager (DEV)"
else
  "${SSH[@]}" "ha store reload >/dev/null 2>&1 || true"
  echo "Copied. First time only: in HA go to Settings > Add-ons > Add-on Store,"
  echo "open 'Local add-ons', install 'Frame Art Manager (DEV)', then rerun this script."
fi
