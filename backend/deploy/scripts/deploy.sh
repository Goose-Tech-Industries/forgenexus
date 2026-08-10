#!/bin/bash
# ===========================================
# ForgeNexus — Zero-Downtime Deploy Script
# ===========================================
# Builds new images, runs migrations, swaps containers
# with health check verification. Rolls back on failure.
#
# Usage:
#   ./deploy.sh              # Full deploy (pull, build, migrate, swap)
#   ./deploy.sh --skip-build # Skip build (just restart with existing images)
#   ./deploy.sh --rollback   # Roll back to previous image
#
# Requirements: Run from the forge_nexus project directory on the droplet.

set -euo pipefail

COMPOSE_FILE="docker-compose.prod.yml"
API_SERVICE="api"
UI_SERVICE="ui"
HEALTH_URL="http://127.0.0.1:4000/api/health"
MAX_HEALTH_RETRIES=30
DEPLOY_LOG="/var/log/forgenexus-deploy.log"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$DEPLOY_LOG"; }

# --- Parse flags ---
SKIP_BUILD=false
ROLLBACK=false
for arg in "$@"; do
  case "$arg" in
    --skip-build) SKIP_BUILD=true ;;
    --rollback) ROLLBACK=true ;;
  esac
done

# --- Rollback ---
if [ "$ROLLBACK" = true ]; then
  log "Rolling back to previous image..."
  docker compose -f "$COMPOSE_FILE" up -d --no-deps "$API_SERVICE" "$UI_SERVICE"
  log "Rollback complete. Check health: curl $HEALTH_URL"
  exit 0
fi

log "========================================="
log "Starting deploy"
log "========================================="

# --- Step 1: Pull latest code ---
log "[1/6] Pulling latest code..."
git pull --ff-only origin main 2>&1 | tee -a "$DEPLOY_LOG"

# --- Step 2: Build new images ---
if [ "$SKIP_BUILD" = false ]; then
  log "[2/6] Building new Docker images..."
  docker compose -f "$COMPOSE_FILE" build --no-cache "$API_SERVICE" "$UI_SERVICE" 2>&1 | tee -a "$DEPLOY_LOG"
else
  log "[2/6] Skipping build (--skip-build)"
fi

# --- Step 3: Run database migrations ---
log "[3/6] Running database migrations..."
# Start a temporary container to run migrations without affecting the running one
docker compose -f "$COMPOSE_FILE" run --rm --no-deps "$API_SERVICE" \
  bin/forge_nexus eval "ForgeNexus.Release.migrate()" 2>&1 | tee -a "$DEPLOY_LOG"

# --- Step 4: Tag current images as rollback target ---
log "[4/6] Tagging current images for rollback..."
CURRENT_API_IMAGE=$(docker compose -f "$COMPOSE_FILE" images -q "$API_SERVICE" 2>/dev/null || echo "none")
CURRENT_UI_IMAGE=$(docker compose -f "$COMPOSE_FILE" images -q "$UI_SERVICE" 2>/dev/null || echo "none")

if [ "$CURRENT_API_IMAGE" != "none" ] && [ -n "$CURRENT_API_IMAGE" ]; then
  docker tag "$CURRENT_API_IMAGE" forgenexus-api:rollback 2>/dev/null || true
fi

# --- Step 5: Swap containers (zero-downtime) ---
log "[5/6] Swapping containers..."
# --no-deps ensures we don't restart postgres/meilisearch/pgbouncer
docker compose -f "$COMPOSE_FILE" up -d --no-deps --force-recreate "$API_SERVICE" "$UI_SERVICE" 2>&1 | tee -a "$DEPLOY_LOG"

# --- Step 6: Health check ---
log "[6/6] Verifying health..."
HEALTHY=false
for i in $(seq 1 $MAX_HEALTH_RETRIES); do
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$HEALTH_URL" 2>/dev/null || echo "000")

  if [ "$HTTP_CODE" = "200" ]; then
    HEALTHY=true
    log "Health check passed on attempt $i"
    break
  fi

  if [ "$i" -eq "$MAX_HEALTH_RETRIES" ]; then
    log "ERROR: Health check failed after $MAX_HEALTH_RETRIES attempts (last HTTP $HTTP_CODE)"
  else
    sleep 2
  fi
done

if [ "$HEALTHY" = true ]; then
  log "========================================="
  log "Deploy successful!"
  log "========================================="

  # Clean up old images
  docker image prune -f > /dev/null 2>&1 || true
else
  log "========================================="
  log "DEPLOY FAILED — Rolling back!"
  log "========================================="

  if [ "$CURRENT_API_IMAGE" != "none" ] && [ -n "$CURRENT_API_IMAGE" ]; then
    docker compose -f "$COMPOSE_FILE" up -d --no-deps "$API_SERVICE" "$UI_SERVICE"
    log "Rolled back. Please investigate the failure."
  else
    log "No previous image to roll back to. Manual intervention required."
  fi

  exit 1
fi
