# ForgeNexus — Production Deployment

No GitHub needed. Copy files directly to your droplet.

## Step 1: Upload files via FileZilla

Connect FileZilla to your DigitalOcean droplet, then:

1. Create `/opt/forgenexus/` on the droplet
2. Upload `forge_nexus/` → `/opt/forgenexus/backend/`
3. Upload `forge_nexus_ui/` → `/opt/forgenexus/frontend/`

**Skip these folders** (they get rebuilt in Docker):
- `node_modules/`
- `_build/`
- `deps/`
- `.elixir_ls/`
- `test-results/`

Your WSL paths (in FileZilla's "Local site" panel):
- Backend: `\\wsl.localhost\Ubuntu\home\rjd4290\projects\forge_nexus`
- Frontend: `\\wsl.localhost\Ubuntu\home\rjd4290\projects\forge_nexus_ui`

## Step 2: Tell Claude on the droplet

SSH into your droplet, open Claude Code, and paste this:

---

```
I need to deploy ForgeNexus. The code is already uploaded to /opt/forgenexus/backend and /opt/forgenexus/frontend.

Do these steps in order:

1. INSTALL DOCKER (if not already installed):
   curl -fsSL https://get.docker.com | sh

2. INSTALL NGINX (if not already installed):
   apt install -y nginx certbot python3-certbot-nginx

3. SET UP THE ENV FILE:
   cd /opt/forgenexus/backend
   cp .env.example .env
   
   Edit .env and fill in:
   - SECRET_KEY_BASE: generate with "openssl rand -hex 64"
   - POSTGRES_PASSWORD: generate with "openssl rand -hex 32"
   - MEILISEARCH_KEY: generate with "openssl rand -hex 32"
   - PHX_HOST: (I'll tell you my domain)
   - ALLOWED_ORIGINS: https://(my domain)

4. FIX THE DOCKER COMPOSE PATH:
   The docker-compose.prod.yml has the UI build context set to ../forge_nexus_ui
   Change it to: /opt/forgenexus/frontend
   
5. BUILD AND START EVERYTHING:
   cd /opt/forgenexus/backend
   docker compose -f docker-compose.prod.yml up -d --build
   
   This starts PostgreSQL, PgBouncer, Meilisearch, the API, and the frontend.
   Wait for everything to be healthy.

6. RUN MIGRATIONS AND SEED:
   docker compose -f docker-compose.prod.yml run --rm api bin/forge_nexus eval "ForgeNexus.Release.migrate()"

7. SET UP NGINX:
   Copy /opt/forgenexus/backend/deploy/nginx/forgenexus.conf to /etc/nginx/sites-enabled/
   Edit it to use my domain name as server_name
   Remove the default site: rm /etc/nginx/sites-enabled/default
   Test: nginx -t
   Reload: systemctl reload nginx

8. SET UP SSL (after DNS is pointed to this server):
   certbot --nginx -d my-domain.com

9. SET UP DAILY BACKUPS:
   cp /opt/forgenexus/backend/deploy/scripts/backup.sh /opt/forgenexus/
   chmod +x /opt/forgenexus/backup.sh
   Add cron: echo "0 3 * * * /opt/forgenexus/backup.sh" | crontab -

10. VERIFY:
    curl http://localhost:4000/api/health
    Should return {"status":"ok"}
```

---

## Step 3: Point your domain

In your domain registrar (or Cloudflare):
- Add an A record pointing to your droplet's IP address
- Once DNS propagates, run certbot for SSL

## Step 4: First use

Visit your domain. You'll see the setup wizard where you:
- Name your community
- Create your admin account
- Set up forum categories

## Updating later

When you make changes locally:
1. FileZilla the changed files to the droplet
2. SSH in and run:
   ```
   cd /opt/forgenexus/backend
   ./deploy/scripts/deploy.sh
   ```
   This rebuilds, migrates, and swaps containers with zero downtime.
   Auto-rolls back if the health check fails.
