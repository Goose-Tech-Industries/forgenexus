#!/usr/bin/env bash
# Nightly logical backup of the ForgeNexus production database.
# Keeps the last 14 daily dumps + last 8 weekly dumps (Sunday).
set -euo pipefail

BACKUP_DIR="/opt/forgenexus/backups"
DAILY_DIR="$BACKUP_DIR/daily"
WEEKLY_DIR="$BACKUP_DIR/weekly"
LOG_FILE="/var/log/forgenexus-backup.log"
TIMESTAMP="$(date -u +%Y%m%d-%H%M%S)"
DOW="$(date -u +%u)"

mkdir -p "$DAILY_DIR" "$WEEKLY_DIR"

DAILY_FILE="$DAILY_DIR/forgenexus-$TIMESTAMP.dump"

log() { echo "[$(date -u +%FT%TZ)] $*" >> "$LOG_FILE"; }

log "Starting backup -> $DAILY_FILE"

if ! docker exec backend-postgres-1 pg_dump -U forge_nexus -d forge_nexus_prod -Fc --no-owner --no-acl > "$DAILY_FILE.tmp"; then
  log "ERROR: pg_dump failed"
  rm -f "$DAILY_FILE.tmp"
  exit 1
fi

mv "$DAILY_FILE.tmp" "$DAILY_FILE"
SIZE="$(du -h "$DAILY_FILE" | cut -f1)"
log "Daily dump complete ($SIZE)"

# Sunday: copy to weekly retention
if [ "$DOW" = "7" ]; then
  cp "$DAILY_FILE" "$WEEKLY_DIR/forgenexus-week-$TIMESTAMP.dump"
  log "Weekly snapshot copied"
fi

# Prune: keep 14 daily, 8 weekly
find "$DAILY_DIR" -name 'forgenexus-*.dump' -mtime +14 -delete
find "$WEEKLY_DIR" -name 'forgenexus-week-*.dump' -mtime +56 -delete

log "Backup complete. Daily files: $(ls -1 "$DAILY_DIR" | wc -l), Weekly: $(ls -1 "$WEEKLY_DIR" | wc -l)"
