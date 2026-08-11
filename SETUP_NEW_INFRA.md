# Infrastructure setup checklist (new pieces wired this session)

This is the activation guide for: **DO snapshot**, **Sentry error tracking**,
**Stripe community subscriptions**, and **UptimeRobot monitoring**. Code is
deployed; you provide the credentials.

## 1. DigitalOcean snapshot (insurance)

The script `/opt/forgenexus/scripts/snapshot-droplet.sh` will create a snapshot
named `forgenexus-<timestamp>` using the doctl CLI (already installed).

**Get a token**:
1. https://cloud.digitalocean.com/account/api/tokens
2. Generate New Token → name "forgenexus-snapshot" → scopes: read + write on droplets → Create
3. Copy the token (starts with `dop_v1_…`)

**Run**:
```bash
DO_API_TOKEN=dop_v1_xxxxxxxxxxxx /opt/forgenexus/scripts/snapshot-droplet.sh
```

That's it. ~2-5 minutes. Output: snapshot listed in your DO console.

Optional: cron a weekly snapshot (the daily DB backup is already in place):
```bash
echo "0 5 * * 0 DO_API_TOKEN=dop_v1_... /opt/forgenexus/scripts/snapshot-droplet.sh weekly-\$(date +%Y%m%d) >> /var/log/forgenexus-snapshot.log 2>&1" | crontab -
```

## 2. Sentry (error tracking)

**Sign up**: https://sentry.io → Create project → pick "Phoenix" for backend
and "SvelteKit" for frontend (or one project for both). Free tier covers
up to 5K events/month.

**Get the DSN(s)** from Project Settings → Client Keys (DSN). They look like:
```
https://abc123@oXXXX.ingest.sentry.io/YYYY
```

**Set env vars in `/opt/forgenexus/backend/.env`**:
```
SENTRY_DSN=https://...@oXXXX.ingest.sentry.io/YYYY
SENTRY_ENV=production
```

Frontend gets `VITE_SENTRY_DSN` baked at build time. Add to the build args
in `docker compose build ui`:
```bash
docker compose -f docker-compose.prod.yml build \
  --build-arg VITE_SENTRY_DSN=https://...@oXXXX.ingest.sentry.io/YYYY \
  ui
```

Then `docker compose up -d --force-recreate api ui`.

**Verify**: in API container, `docker exec backend-api-1 /app/bin/forge_nexus rpc 'Sentry.capture_message("hello from forgenexus")'` → check Sentry dashboard.

## 3. Stripe (community SaaS subscriptions)

**Sign up / log in**: https://dashboard.stripe.com. Enable Test Mode
(toggle in top-right) for everything below.

### a) Create the price catalog (test mode)

Stripe → Catalog → Products → New Product. Repeat for each tier:

| Plan | Price | Recurring |
|---|---|---|
| Forum | $19.00 USD | Monthly |
| Community | $39.00 USD | Monthly |
| Creator | $79.00 USD | Monthly |
| Platform | $225.00 USD | Monthly |
| Enterprise | $350.00 USD | Monthly |
| Houses — base | $149.00 USD | Monthly |
| Houses — per additional creator | $25.00 USD | Monthly |

For each, copy the **Price ID** (starts with `price_…`).

Houses is two separate Prices, not one — checkout adds them as two line
items on the same subscription (base at quantity 1, per-creator at
quantity = current member count minus the founder). See
`ForgeNexus.Billing.fetch_houses_line_items/1`.

### b) Get API keys

Stripe → Developers → API keys:
- **Secret key** (`sk_test_…`)
- **Publishable key** (`pk_test_…`)

### c) Set the webhook endpoint

Stripe → Developers → Webhooks → Add endpoint:
- URL: `https://forum.tcgaming.quest/api/webhooks/stripe`
- Events: `checkout.session.completed`, `customer.subscription.created`,
  `customer.subscription.updated`, `customer.subscription.deleted`,
  `invoice.payment_failed`
- Copy the signing secret (`whsec_…`)

### d) Set env vars in `/opt/forgenexus/backend/.env`

```
STRIPE_SECRET_KEY=sk_test_xxxxxxxxxxxx
STRIPE_PUBLISHABLE_KEY=pk_test_xxxxxxxxxxxx
STRIPE_WEBHOOK_SECRET=whsec_xxxxxxxxxxxx

STRIPE_PRICE_FORUM=price_xxxxxxxxxxxx
STRIPE_PRICE_COMMUNITY=price_xxxxxxxxxxxx
STRIPE_PRICE_CREATOR=price_xxxxxxxxxxxx
STRIPE_PRICE_PLATFORM=price_xxxxxxxxxxxx
STRIPE_PRICE_ENTERPRISE=price_xxxxxxxxxxxx

STRIPE_PRICE_HOUSES_BASE=price_xxxxxxxxxxxx
STRIPE_PRICE_HOUSES_PER_CREATOR=price_xxxxxxxxxxxx
```

### e) Run the migration

```bash
docker exec backend-api-1 /app/bin/forge_nexus eval 'ForgeNexus.Release.migrate()'
```

(or via mix in dev: `mix ecto.migrate`)

### f) Restart api

```bash
cd /opt/forgenexus/backend
docker compose -f docker-compose.prod.yml up -d --force-recreate api
```

### g) Test end-to-end

1. Create a community via your API or the admin UI (must have `owner_id` = you)
2. Visit `https://forum.tcgaming.quest/billing`
3. Pick the community, click Subscribe on Forum tier
4. You'll be redirected to Stripe Checkout — use test card `4242 4242 4242 4242` (any future expiry, any CVC, any ZIP)
5. After paying, redirect back to `/billing/success`
6. Check `community.plan == "forum"` and `community.plan_status == "active"` in DB
7. Stripe → Webhooks → your endpoint → confirm event was delivered (200)

If anything fails: `docker logs --tail 100 backend-api-1 | grep -iE 'stripe|billing'`.

## 4. UptimeRobot (free monitoring)

**Sign up**: https://uptimerobot.com (free tier: 50 monitors, 5-min interval)

**Add these monitors** (HTTP(s) keyword type, "200" expected):
| Name | URL | Type |
|---|---|---|
| ForgeNexus home | `https://forum.tcgaming.quest` | HTTP(s) |
| ForgeNexus API health | `https://forum.tcgaming.quest/api/health` | Keyword: `"status":"ok"` |
| TC Gaming home | `https://tcgaming.quest` | HTTP(s) |

**Notify on failure**: add your email (and optionally a Discord webhook) in
Notification Settings.

**That's it.** When the droplet goes down or the app crashes, you get an email
within 5 minutes. Combined with Sentry (which catches errors that don't
crash the server), you've got a real observability stack.

## What this all costs

| Service | Tier | Cost |
|---|---|---|
| DigitalOcean snapshots | $0.06/GB-month | ~$0.30/mo per snapshot of this droplet |
| Sentry | Free | 5K events/mo |
| Stripe | Free | 2.9% + $0.30 per charge (already factored into your revenue model) |
| UptimeRobot | Free | 50 monitors, 5-min |
| **Total** | | **~$0.30/mo** until you have real revenue |

## Ordering for tonight

1. **Snapshot first** — 5 min, gives you a rollback point before anything else
2. **UptimeRobot second** — 10 min, gives you visibility starting now
3. **Sentry third** — 20 min, requires rebuild
4. **Stripe last** — 30-60 min for full e2e test, requires test card walkthrough

If you only have time for one, do **Stripe**. That's the one that actually
makes the platform a business.
