#!/bin/bash
# ===========================================
# ForgeNexus — Database Backup Script
# ===========================================
# Dumps PostgreSQL, compresses with gzip, rotates old backups.
# Keep: 7 daily, 4 weekly (Sunday)
#
# Crontab (daily at 3am):
#   0 3 * * * /home/forge_nexus/deploy/scripts/backup.sh >> /var/log/forgenexus-backup.log 2>&1
#
# Restore:
#   gunzip -c backup.sql.gz | docker exec -i <container> psql -U forge_nexus forge_nexus_prod

set -euo pipefail

# --- Config ---
BACKUP_DIR="/backups/forgenexus"
DB_CONTAINER="forge_nexus-postgres-1"
DB_USER="forge_nexus"
DB_NAME="forge_nexus_prod"
DAILY_KEEP=7
WEEKLY_KEEP=4
DATE=$(date +%Y-%m-%d_%H%M)
DAY_OF_WEEK=$(date +%u)

# --- Ensure backup directory exists ---
mkdir -p "$BACKUP_DIR/daily"
mkdir -p "$BACKUP_DIR/weekly"

echo "[$DATE] Starting backup..."

# --- Dump database ---
DAILY_FILE="$BACKUP_DIR/daily/${DB_NAME}_${DATE}.sql.gz"
docker exec "$DB_CONTAINER" pg_dump -U "$DB_USER" "$DB_NAME" --no-owner --no-acl | gzip > "$DAILY_FILE"

SIZE=$(du -h "$DAILY_FILE" | cut -f1)
echo "[$DATE] Daily backup created: $DAILY_FILE ($SIZE)"

# --- Weekly backup on Sunday (day 7) ---
if [ "$DAY_OF_WEEK" -eq 7 ]; then
  WEEKLY_FILE="$BACKUP_DIR/weekly/${DB_NAME}_weekly_${DATE}.sql.gz"
  cp "$DAILY_FILE" "$WEEKLY_FILE"
  echo "[$DATE] Weekly backup created: $WEEKLY_FILE"

  # Rotate weekly (keep last N)
  ls -1t "$BACKUP_DIR/weekly/"*.sql.gz 2>/dev/null | tail -n +$((WEEKLY_KEEP + 1)) | xargs -r rm
  echo "[$DATE] Rotated weekly backups (keeping $WEEKLY_KEEP)"
fi

# --- Rotate daily (keep last N) ---
ls -1t "$BACKUP_DIR/daily/"*.sql.gz 2>/dev/null | tail -n +$((DAILY_KEEP + 1)) | xargs -r rm
echo "[$DATE] Rotated daily backups (keeping $DAILY_KEEP)"

echo "[$DATE] Backup complete."
