# Cloudflare Setup for ForgeNexus

Free tier gives you: global CDN, DDoS protection, HTTP/3, Brotli, bot management, and analytics.

## 1. Add Your Site

1. Go to [dash.cloudflare.com](https://dash.cloudflare.com)
2. Click **Add a site** → enter your domain
3. Select the **Free** plan
4. Cloudflare will scan your existing DNS records
5. Update your domain's nameservers to the ones Cloudflare provides (at your registrar)

## 2. SSL/TLS Settings

Go to **SSL/TLS → Overview**:
- Set mode to **Full (Strict)** — requires a valid cert on your origin (Let's Encrypt)
- This means: Browser ↔ Cloudflare (encrypted) ↔ Your server (encrypted)

Go to **SSL/TLS → Edge Certificates**:
- Enable **Always Use HTTPS** ✓
- Enable **Automatic HTTPS Rewrites** ✓
- Set **Minimum TLS Version** to **1.2**
- Enable **TLS 1.3** ✓

## 3. Speed Settings

Go to **Speed → Optimization**:
- Enable **Brotli** ✓ (20-30% smaller than gzip)
- Enable **HTTP/2** ✓ (should be on by default)
- Enable **HTTP/3 (QUIC)** ✓ — huge latency improvement on mobile

Go to **Speed → Optimization → Content Optimization**:
- Enable **Auto Minify** for JavaScript, CSS, HTML ✓
- Enable **Early Hints** ✓ (sends 103 status for preloading)

## 4. Caching

Go to **Caching → Configuration**:
- Set **Browser Cache TTL** to **Respect Existing Headers** (our Nginx config sets proper headers)
- Set **Caching Level** to **Standard**

Go to **Rules → Page Rules** (3 free rules):

**Rule 1: Cache static assets aggressively**
- URL: `yourdomain.com/_app/*`
- Setting: Cache Level → Cache Everything, Edge Cache TTL → 1 month

**Rule 2: Cache uploaded media**
- URL: `yourdomain.com/uploads/*`
- Setting: Cache Level → Cache Everything, Edge Cache TTL → 1 week

**Rule 3: Bypass cache for API**
- URL: `yourdomain.com/api/*`
- Setting: Cache Level → Bypass

## 5. Firewall / Security

Go to **Security → Settings**:
- Set **Security Level** to **Medium**
- Enable **Browser Integrity Check** ✓
- Enable **Bot Fight Mode** ✓ (blocks known bad bots)

Go to **Security → WAF**:
- The free tier includes basic managed rules — enable them

## 6. Network

Go to **Network**:
- Enable **HTTP/3 (with QUIC)** ✓
- Enable **WebSockets** ✓ (required for ForgeNexus live features)
- Enable **gRPC** ✓ (future-proofing)

## 7. Update Nginx for Cloudflare

After enabling Cloudflare, all traffic comes from Cloudflare IPs. You need to:

1. **Restore real visitor IPs** — add to your Nginx config (already included in our config):
```nginx
# Cloudflare IP ranges (add to http block in nginx.conf)
set_real_ip_from 173.245.48.0/20;
set_real_ip_from 103.21.244.0/22;
set_real_ip_from 103.22.200.0/22;
set_real_ip_from 103.31.4.0/22;
set_real_ip_from 141.101.64.0/18;
set_real_ip_from 108.162.192.0/18;
set_real_ip_from 190.93.240.0/20;
set_real_ip_from 188.114.96.0/20;
set_real_ip_from 197.234.240.0/22;
set_real_ip_from 198.41.128.0/17;
set_real_ip_from 162.158.0.0/15;
set_real_ip_from 104.16.0.0/13;
set_real_ip_from 104.24.0.0/14;
set_real_ip_from 172.64.0.0/13;
set_real_ip_from 131.0.72.0/22;
# IPv6
set_real_ip_from 2400:cb00::/32;
set_real_ip_from 2606:4700::/32;
set_real_ip_from 2803:f800::/32;
set_real_ip_from 2405:b500::/32;
set_real_ip_from 2405:8100::/32;
set_real_ip_from 2a06:98c0::/29;
set_real_ip_from 2c0f:f248::/32;
real_ip_header CF-Connecting-IP;
```

2. **Block direct access** (optional but recommended) — only allow Cloudflare IPs to hit port 443:
```bash
# UFW rules
sudo ufw allow from 173.245.48.0/20 to any port 443
sudo ufw allow from 103.21.244.0/22 to any port 443
# ... (add all Cloudflare ranges)
sudo ufw deny 443
```

## 8. DNS Records

In Cloudflare DNS, make sure:
- `A` record: `yourdomain.com` → `your.droplet.ip` (proxied, orange cloud ✓)
- `A` record: `www` → `your.droplet.ip` (proxied, orange cloud ✓)

## 9. Verify

After setup, verify:
```bash
# Check HTTP/3
curl -I --http3 https://yourdomain.com

# Check headers
curl -I https://yourdomain.com
# Should see: cf-ray, cf-cache-status headers

# Check SSL grade
# Visit: https://www.ssllabs.com/ssltest/analyze.html?d=yourdomain.com
```

## Performance Impact

| Metric | Without Cloudflare | With Cloudflare |
|--------|-------------------|-----------------|
| Global latency | 100-300ms (single server) | 10-50ms (edge cached) |
| DDoS protection | Nginx rate limits only | Enterprise-grade |
| Bandwidth cost | All from your droplet | 60-80% served from edge |
| HTTP version | HTTP/2 | HTTP/3 QUIC |
| Compression | gzip (your server) | Brotli (Cloudflare edge) |
