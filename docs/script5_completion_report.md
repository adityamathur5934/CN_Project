# Script 5 — Completion Report
> HTTPS / TLS | P2 (Mac 2 — Aditya)

---

## Status: ✅ COMPLETE

**Done condition met:** HTTPS works with proper certificate validation (no `-k`).
Both `X-Backend: A` and `X-Backend: B` confirmed over HTTPS. HTTP redirects to HTTPS.

---

## What Was Done

| Step | Action | Result |
|------|--------|--------|
| 1 | Backed up Script 4 nginx config | `team.conf.script4.bak` |
| 2 | Generated self-signed TLS cert | RSA 2048, SAN, 1 year validity |
| 3 | Added HTTPS server block to nginx | Port 8443, TLSv1.2/1.3 |
| 4 | Added HTTP → HTTPS redirect | Port 8080 returns 301 |
| 5 | Installed cert in macOS Keychain | `sudo security add-trusted-cert` |
| 6 | Pointed Mac 2 DNS to Om's server | `networksetup -setdnsservers Wi-Fi 10.7.15.236 8.8.8.8` |
| 7 | Added `/etc/hosts` entry | `10.7.17.151 app.team1.test api.team1.test` |
| 8 | Validated all 5 checks pass | See test results below |

---

## Certificate Details

```
File:       configs/tls/team1.test.crt
Key:        configs/tls/team1.test.key (keep private — do not share)
CN:         app.team1.test
SAN:        DNS:app.team1.test, DNS:api.team1.test, IP:10.7.17.151
Valid:      Oct 1 2026 → Oct 1 2027  (1 year)
Algorithm:  RSA 2048-bit
Signature:  sha256WithRSAEncryption
```

---

## nginx Configuration

**Config file:** `/opt/homebrew/etc/nginx/servers/team.conf`
**Copy in project:** `configs/nginx/nginx_http.conf` (update also saved here)

```nginx
upstream backend_nodes {
    server 10.7.10.0:3001;    # Backend A — Mac 3 (Krishiv)
    server 10.7.16.36:3002;   # Backend B — Mac 4 (Vaidehi)
}

# HTTP — redirects to HTTPS
server {
    listen      8080;
    server_name app.team1.test 10.7.17.151;
    location /health { return 200 '...'; }   # bypass — stays HTTP
    location / { return 301 https://$host:8443$request_uri; }
}

# HTTPS — TLS termination + reverse proxy
server {
    listen      8443 ssl;
    server_name app.team1.test 10.7.17.151;
    ssl_certificate     .../team1.test.crt;
    ssl_certificate_key .../team1.test.key;
    ssl_protocols       TLSv1.2 TLSv1.3;
    ssl_ciphers         HIGH:!aNULL:!MD5;
    location / {
        proxy_pass http://backend_nodes;
        proxy_set_header X-Forwarded-Proto https;
        proxy_pass_header X-Backend;
    }
}
```

---

## Test Results (all ✅)

```
[1/5] DNS resolution
  ✅ app.team1.test → 10.7.17.151

[2/5] HTTPS without -k
  ✅ curl https://app.team1.test:8443/health — HTTP 200 (no -k)

[3/5] TLS protocol and cipher
  ✅ Protocol: TLSv1.3
  ✅ Cipher:   TLS_AES_256_GCM_SHA384

[4/5] HTTP → HTTPS redirect
  ✅ HTTP 8080 → 301 Moved Permanently
  ✅ Location: https://app.team1.test:8443/api/status

[5/5] Load balancer over HTTPS (8 requests)
  Request 1 → X-Backend: B  {"backend": "B", "status": "ok"}
  Request 2 → X-Backend: A  {"backend": "A", "status": "ok"}
  Request 3 → X-Backend: B  {"backend": "B", "status": "ok"}
  Request 4 → X-Backend: A  {"backend": "A", "status": "ok"}
  Request 5 → X-Backend: B  {"backend": "B", "status": "ok"}
  Request 6 → X-Backend: A  {"backend": "A", "status": "ok"}
  Request 7 → X-Backend: B  {"backend": "B", "status": "ok"}
  Request 8 → X-Backend: A  {"backend": "A", "status": "ok"}
  Backend A: 4 | Backend B: 4 | Errors: 0
  ✅ Perfect round-robin over HTTPS
```

---

## TLS Handshake Explanation (for viva)

When a client connects to `https://app.team1.test:8443`:

1. **ClientHello** — client sends supported TLS versions, cipher suites, random nonce
2. **ServerHello** — nginx selects TLS 1.3, cipher `TLS_AES_256_GCM_SHA384`, sends its random nonce
3. **Certificate** — nginx sends `team1.test.crt` (clients verify against trusted CAs)
4. **Key Exchange** — both sides derive a shared session key (ECDHE in TLS 1.3)
5. **Finished** — both sides confirm handshake with a MAC; encrypted channel established
6. **Application Data** — all HTTP traffic is now encrypted; proxied to backends as plain HTTP internally

Backends (Mac 3 and Mac 4) receive **plain HTTP** from nginx — TLS terminates at the edge.

---

## Certificate Trust — Sharing with Teammates

Every Mac that wants to reach `https://app.team1.test:8443` **without `-k`** must trust the certificate.

### Share the certificate
Send `configs/tls/team1.test.crt` to Om (P1) and Vaidehi (P4).
**Never share `team1.test.key`.**

### Install on macOS (Om, Vaidehi)
```bash
# Copy the .crt to their Mac, then run:
sudo security add-trusted-cert -d -r trustRoot \
  -k /Library/Keychains/System.keychain \
  /path/to/team1.test.crt
```

### Add DNS resolution (each Mac)
Either point DNS to Om's server, or add to `/etc/hosts`:
```bash
# Option A — use Om's DNS (recommended)
networksetup -setdnsservers Wi-Fi 10.7.15.236 8.8.8.8

# Option B — /etc/hosts entry
echo "10.7.17.151 app.team1.test api.team1.test" | sudo tee -a /etc/hosts
```

### Verify on their Mac
```bash
curl -s https://app.team1.test:8443/api/status
# Expected: {"backend": "A", "status": "ok"}  OR  {"backend": "B", "status": "ok"}
# No SSL warnings. No -k needed.
```

---

## nginx Management

```bash
brew services restart nginx          # full restart
nginx -s reload                      # graceful reload (no connection drop)
nginx -t                             # test syntax before reload
tail -f /opt/homebrew/var/log/nginx/team_access.log
tail -f /opt/homebrew/var/log/nginx/team_error.log
```

---

## Assumptions

- Port 8443 used instead of 443 (Homebrew nginx runs without root — no marks deducted)
- Self-signed certificate — clients must install trust manually
- Backends remain on plain HTTP internally — TLS only at the edge (correct design)

---

## Next Steps

| Script | Action |
|--------|--------|
| Script 7 | Wireshark: capture DNS query, TCP handshake, TLS handshake, encrypted data |
| Script 8 | Phase 1 failure tests (stop backends, wrong DNS, wrong port) |
| Share cert | Send `team1.test.crt` to Om and Vaidehi |
