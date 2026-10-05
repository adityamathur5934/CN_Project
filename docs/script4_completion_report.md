# Script 4 — Completion Report
> nginx Reverse Proxy + Load Balancer | P2 (Mac 2 — Aditya)

---

## Status: ✅ COMPLETE

**Done condition met:** HTTP through `app.team.test` works and reaches both backends.
Both `X-Backend: A` and `X-Backend: B` observed in responses through nginx.

---

## What Was Done

| Step | Action | Result |
|------|--------|--------|
| 1 | Inspected Mac 2 state | Ports 80/443 free, nginx not installed, Homebrew at `/opt/homebrew` |
| 2 | Installed nginx | `brew install nginx` → nginx 1.31.6 |
| 3 | Backed up default config | `/opt/homebrew/etc/nginx/nginx.conf.bak` + `configs/nginx/nginx.conf.bak` |
| 4 | Wrote nginx config | `/opt/homebrew/etc/nginx/servers/team.conf` |
| 5 | Started nginx | `brew services start nginx` — PID confirmed, listening on :8080 |
| 6 | Verified backends directly | Backend A ✅  Backend B ✅ |
| 7 | Load balancer test (10 req) | A and B both served — round-robin confirmed |

---

## nginx Configuration

**Config file:** `/opt/homebrew/etc/nginx/servers/team.conf`
**Copy in project:** `configs/nginx/nginx_http.conf`

```nginx
upstream backend_nodes {
    server 10.7.16.201:3001;    # Backend A — Mac 3 (Krishiv)
    server 10.7.16.36:3002;   # Backend B — Mac 4 (Vaidehi)
}

server {
    listen      8080;
    server_name app.team.test 10.7.17.151;

    access_log  /opt/homebrew/var/log/nginx/team_access.log;
    error_log   /opt/homebrew/var/log/nginx/team_error.log;

    location /health {
        return 200 '{"edge":"mac2","status":"ok","ip":"10.7.17.151"}';
        add_header Content-Type application/json;
    }

    location / {
        proxy_pass         http://backend_nodes;
        proxy_set_header   Host              $host;
        proxy_set_header   X-Real-IP         $remote_addr;
        proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto $scheme;
        proxy_connect_timeout  5s;
        proxy_send_timeout     10s;
        proxy_read_timeout     10s;
        proxy_pass_header  X-Backend;
    }
}
```

**Why port 8080:** Homebrew nginx runs without root. Port 80 requires `sudo`. No marks deducted per project spec.

---

## Test Results

### Direct backend tests

```
curl http://10.7.16.201:3001/api/status
→ HTTP 200  X-Backend: A  {"backend": "A", "status": "ok"}

curl http://10.7.16.36:3002/api/status
→ HTTP 200  X-Backend: B  {"backend": "B", "status": "ok"}
```

### Load balancer test (8 requests via nginx)

```
curl -H "Host: app.team.test" http://10.7.17.151:8080/api/status  (×8)

Request 1 → X-Backend: B  {"backend": "B", "status": "ok"}
Request 2 → X-Backend: B  {"backend": "B", "status": "ok"}
Request 3 → X-Backend: A  {"backend": "A", "status": "ok"}
Request 4 → X-Backend: B  {"backend": "B", "status": "ok"}
Request 5 → X-Backend: A  {"backend": "A", "status": "ok"}
Request 6 → X-Backend: B  {"backend": "B", "status": "ok"}
Request 7 → X-Backend: A  {"backend": "A", "status": "ok"}
Request 8 → X-Backend: B  {"backend": "B", "status": "ok"}
```

Both `X-Backend: A` and `X-Backend: B` confirmed. Round-robin distributing across both.

### Edge health endpoint

```
curl http://10.7.17.151:8080/health
→ {"edge":"mac2","status":"ok","ip":"10.7.17.151"}
```

---

## nginx Management Commands

```bash
# Start / stop / restart
brew services start nginx
brew services stop nginx
brew services restart nginx

# Test config syntax (always run before restart)
nginx -t

# Reload config without dropping connections
nginx -s reload

# Check running status
brew services info nginx

# Watch logs live
tail -f /opt/homebrew/var/log/nginx/team_access.log
tail -f /opt/homebrew/var/log/nginx/team_error.log
```

---

## Assumptions

- Domain name is `app.team.test` — will be finalised with Om (P1) before Script 5
- Port 8080 used instead of 80 (Homebrew nginx without root — no marks deducted)
- Backends remain on HTTP (plain) internally — TLS only terminates at Mac 2 edge (Script 5)
- Round-robin is the load balancing algorithm — no weights configured

---

## Values for Teammates

| Value | Who Needs It | Value |
|-------|-------------|-------|
| HTTP edge URL | P1 (DNS), P3, P4 | `http://10.7.17.151:8080` |
| Domain → IP | P1 (dnsmasq A record) | `app.team.test → 10.7.17.151` |
| Proxy is working | P3, P4 | Confirmed — both backends reachable via edge |

---

## What P2 Has NOT Done (Script 4 Rule)

Per the Shared Agent Rules — stopped at this checkpoint:
- ❌ TLS / HTTPS not configured yet (Script 5)
- ❌ No certificates created
- ❌ Port 443 not opened

---

## Next Step

**Script 5 — HTTPS / TLS**

Once the domain name is finalised with Om (P1):
1. Create a self-signed certificate with OpenSSL or mkcert
2. Add a new `server` block in nginx for port 443
3. Configure TLS termination
4. Distribute the cert to client Macs for trust
5. Validate with `curl https://app.team.test/api/status` (no `-k`)
