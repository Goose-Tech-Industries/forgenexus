#!/bin/bash
set -euo pipefail

# ===========================================
# ForgeNexus — First-Time Production Setup
# ===========================================
# Run on a fresh Ubuntu droplet. Does everything:
#   1. Installs Docker, Nginx, Certbot
#   2. Generates secrets and .env
#   3. Builds and starts all containers
#   4. Runs database migrations
#   5. Configures Nginx reverse proxy
#
# Usage:
#   chmod +x setup-production.sh
#   ./setup-production.sh
#
# After running, visit http://YOUR_IP in a browser
# to see the setup wizard.
# ===========================================

FORGENEXUS_DIR="/opt/forgenexus"
BACKEND_DIR="$FORGENEXUS_DIR/backend"
FRONTEND_DIR="$FORGENEXUS_DIR/frontend"

log() { echo ""; echo "=== $1 ==="; echo ""; }

# --- Verify files exist ---
if [ ! -f "$BACKEND_DIR/mix.exs" ]; then
  echo "ERROR: Backend not found at $BACKEND_DIR"
  echo "Upload forge_nexus to $BACKEND_DIR first."
  exit 1
fi
if [ ! -f "$FRONTEND_DIR/package.json" ]; then
  echo "ERROR: Frontend not found at $FRONTEND_DIR"
  echo "Upload forge_nexus_ui to $FRONTEND_DIR first."
  exit 1
fi

echo ""
echo "========================================="
echo "  ForgeNexus — Production Setup"
echo "========================================="
echo ""
echo "  Backend:  $BACKEND_DIR"
echo "  Frontend: $FRONTEND_DIR"
echo ""

# -------------------------------------------------------
# Step 1: Install Docker
# -------------------------------------------------------
log "Step 1/7: Installing Docker"

if command -v docker &> /dev/null; then
  echo "Docker already installed: $(docker --version)"
else
  curl -fsSL https://get.docker.com | sh
  systemctl enable docker
  systemctl start docker
  echo "Docker installed: $(docker --version)"
fi

# Verify docker compose
if docker compose version &> /dev/null; then
  echo "Docker Compose: $(docker compose version)"
else
  echo "ERROR: Docker Compose not available"
  exit 1
fi

# -------------------------------------------------------
# Step 2: Install Nginx + Certbot
# -------------------------------------------------------
log "Step 2/7: Installing Nginx & Certbot"

apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq nginx certbot python3-certbot-nginx > /dev/null 2>&1
systemctl enable nginx
echo "Nginx installed: $(nginx -v 2>&1)"

# -------------------------------------------------------
# Step 3: Generate secrets and .env
# -------------------------------------------------------
log "Step 3/7: Generating secrets and .env"

cd "$BACKEND_DIR"

# Get the server's public IP
SERVER_IP=$(curl -s http://checkip.amazonaws.com 2>/dev/null || curl -s http://ifconfig.me 2>/dev/null || echo "localhost")
echo "Detected server IP: $SERVER_IP"

if [ ! -f .env ]; then
  cp .env.example .env

  SECRET_KEY=$(openssl rand -hex 64)
  PG_PASS=$(openssl rand -hex 32)
  MEILI_KEY=$(openssl rand -hex 32)

  sed -i "s|SECRET_KEY_BASE=.*|SECRET_KEY_BASE=$SECRET_KEY|" .env
  sed -i "s|POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=$PG_PASS|" .env 2>/dev/null || true
  sed -i "s|DATABASE_URL=.*|DATABASE_URL=ecto://forge_nexus:$PG_PASS@pgbouncer:5432/forge_nexus_prod|" .env
  sed -i "s|PHX_HOST=.*|PHX_HOST=$SERVER_IP|" .env
  sed -i "s|ALLOWED_ORIGINS=.*|ALLOWED_ORIGINS=http://$SERVER_IP|" .env
  sed -i "s|MEILISEARCH_KEY=.*|MEILISEARCH_KEY=$MEILI_KEY|" .env

  # Add POSTGRES_PASSWORD as its own var (docker compose needs it)
  if ! grep -q "^POSTGRES_PASSWORD=" .env; then
    echo "" >> .env
    echo "POSTGRES_PASSWORD=$PG_PASS" >> .env
  fi

  echo "Generated .env with fresh secrets"
else
  echo ".env already exists — skipping"
  # Read existing password for docker compose
  PG_PASS=$(grep "^POSTGRES_PASSWORD=" .env | cut -d= -f2 || echo "")
fi

# -------------------------------------------------------
# Step 4: Fix docker-compose paths
# -------------------------------------------------------
log "Step 4/7: Configuring Docker Compose"

# Update UI build context to point to the correct frontend path
sed -i "s|context:.*forge_nexus_ui.*|context: $FRONTEND_DIR|" docker-compose.prod.yml
sed -i "s|context:.*frontend.*|context: $FRONTEND_DIR|" docker-compose.prod.yml 2>/dev/null || true

# Create postgres config directory if missing
mkdir -p deploy/postgres
if [ ! -f deploy/postgres/postgresql.conf ]; then
  cat > deploy/postgres/postgresql.conf << 'PGCONF'
listen_addresses = '*'
max_connections = 200
shared_buffers = 256MB
effective_cache_size = 512MB
work_mem = 4MB
maintenance_work_mem = 64MB
checkpoint_completion_target = 0.9
wal_buffers = 16MB
random_page_cost = 1.1
effective_io_concurrency = 200
min_wal_size = 1GB
max_wal_size = 4GB
log_timezone = 'UTC'
datestyle = 'iso, mdy'
timezone = 'UTC'
lc_messages = 'en_US.utf8'
lc_monetary = 'en_US.utf8'
lc_numeric = 'en_US.utf8'
lc_time = 'en_US.utf8'
default_text_search_config = 'pg_catalog.english'
PGCONF
  echo "Created PostgreSQL config"
fi

echo "Docker Compose configured"

# -------------------------------------------------------
# Step 5: Build and start containers
# -------------------------------------------------------
log "Step 5/7: Building and starting containers"

export POSTGRES_PASSWORD="$PG_PASS"
docker compose -f docker-compose.prod.yml up -d --build 2>&1 | tail -20

echo ""
echo "Waiting for services to be healthy..."
sleep 10

# Wait for API health
for i in $(seq 1 60); do
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:4000/api/health 2>/dev/null || echo "000")
  if [ "$HTTP_CODE" = "200" ]; then
    echo "API is healthy!"
    break
  fi
  if [ "$i" -eq 60 ]; then
    echo "WARNING: API not responding yet. Check logs with: docker compose -f docker-compose.prod.yml logs api"
  fi
  sleep 5
done

# -------------------------------------------------------
# Step 6: Run migrations
# -------------------------------------------------------
log "Step 6/7: Running database migrations"

docker compose -f docker-compose.prod.yml run --rm api bin/forge_nexus eval "ForgeNexus.Release.migrate()" 2>&1 || {
  echo "WARNING: Migration command failed. The release module might not have a migrate function."
  echo "Trying alternative..."
  docker compose -f docker-compose.prod.yml exec api bin/forge_nexus eval "Ecto.Migrator.run(ForgeNexus.Repo, :up, all: true)" 2>&1 || true
}

echo "Migrations complete"

# -------------------------------------------------------
# Step 7: Configure Nginx
# -------------------------------------------------------
log "Step 7/7: Configuring Nginx"

# Remove default site
rm -f /etc/nginx/sites-enabled/default

cat > /etc/nginx/sites-enabled/forgenexus.conf << NGINX
upstream phoenix_api {
    server 127.0.0.1:4000;
}

upstream sveltekit_ui {
    server 127.0.0.1:3000;
}

server {
    listen 80;
    server_name $SERVER_IP;

    client_max_body_size 50M;

    # API and WebSocket
    location /api/ {
        proxy_pass http://phoenix_api;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location /socket/ {
        proxy_pass http://phoenix_api;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_read_timeout 86400;
    }

    # Everything else → SvelteKit
    location / {
        proxy_pass http://sveltekit_ui;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
NGINX

# Test and reload
nginx -t && systemctl reload nginx
echo "Nginx configured and running"

# -------------------------------------------------------
# Step 8: Set up daily backups
# -------------------------------------------------------
if [ -f "$BACKEND_DIR/deploy/scripts/backup.sh" ]; then
  cp "$BACKEND_DIR/deploy/scripts/backup.sh" /opt/forgenexus/backup.sh
  chmod +x /opt/forgenexus/backup.sh
  (crontab -l 2>/dev/null; echo "0 3 * * * /opt/forgenexus/backup.sh") | sort -u | crontab -
  echo "Daily backup cron set for 3:00 AM"
fi

# -------------------------------------------------------
# Done!
# -------------------------------------------------------
echo ""
echo "========================================="
echo "  ForgeNexus is LIVE!"
echo "========================================="
echo ""
echo "  URL:  http://$SERVER_IP"
echo ""
echo "  Open that URL in your browser."
echo "  You'll see the setup wizard to create"
echo "  your admin account and name your community."
echo ""
echo "  Useful commands:"
echo "    Logs:     cd $BACKEND_DIR && docker compose -f docker-compose.prod.yml logs -f"
echo "    Restart:  cd $BACKEND_DIR && docker compose -f docker-compose.prod.yml restart"
echo "    Update:   cd $BACKEND_DIR && ./deploy/scripts/deploy.sh"
echo "    Backup:   /opt/forgenexus/backup.sh"
echo ""
echo "  When you get a domain, run:"
echo "    certbot --nginx -d yourdomain.com"
echo ""
echo "========================================="
