#!/usr/bin/env bash
# Take a DigitalOcean droplet snapshot.
# Requires: DO_API_TOKEN env var with a Personal Access Token that has
# write scope on droplets.
# Usage:
#   DO_API_TOKEN=dop_v1_... ./snapshot-droplet.sh [snapshot-name]
set -euo pipefail

if [ -z "${DO_API_TOKEN:-}" ]; then
  echo "ERROR: DO_API_TOKEN not set." >&2
  echo "Create one at https://cloud.digitalocean.com/account/api/tokens (write scope)." >&2
  exit 1
fi

NAME="${1:-forgenexus-$(date -u +%Y%m%d-%H%M%S)}"

# Authenticate doctl with the token.
doctl auth init -t "$DO_API_TOKEN" --context forgenexus >/dev/null
doctl auth switch --context forgenexus >/dev/null

# Find the droplet that owns this server's public IPv4.
PUBLIC_IP="$(curl -s -4 ifconfig.me)"
DROPLET_ID="$(doctl compute droplet list --format ID,PublicIPv4 --no-header | awk -v ip="$PUBLIC_IP" '$2 == ip {print $1}')"

if [ -z "$DROPLET_ID" ]; then
  echo "ERROR: could not find droplet with public IP $PUBLIC_IP." >&2
  echo "Snapshot via the DO web UI: cloud.digitalocean.com → Droplets → … → Take Snapshot" >&2
  exit 1
fi

echo "Taking snapshot of droplet $DROPLET_ID as '$NAME'..."
doctl compute droplet-action snapshot "$DROPLET_ID" --snapshot-name "$NAME" --wait
echo "Snapshot complete: $NAME"
doctl compute snapshot list --format ID,Name,Created --no-header | grep "$NAME" || true
