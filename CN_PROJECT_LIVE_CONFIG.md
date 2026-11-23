# CN Project — Live Configuration

## 1. Team

| Machine | Member | Role |
|---|---|---|
| Mac 1 | Om | Private DNS + Client |
| Mac 2 | Aditya | Edge / Reverse Proxy / Load Balancer |
| Mac 3 | Krishiv | Backend A |
| Mac 4 | Vaidehi | Backend B + Client |

---

## 2. Network

- Network: `10.7.0.0/19`
- Subnet mask: `255.255.224.0`
- Broadcast: `10.7.31.255`
- Gateway: `10.7.0.1`
- Active interface: `en0`

---

## 3. Machine Configuration

### Mac 1 — Om

- Role: DNS + Client
- IPv4: `10.7.10.8`
- Interface: `en0`
- Gateway: `10.7.0.1`
- DNS service: `dnsmasq`
- DNS port: `53/UDP`
- TTL: `30s`
- Backup DNS: `10.7.2.96` (Mac 4 / Vaidehi — Extension A)

### Mac 2 — Aditya

- Role: Edge / Reverse Proxy / Load Balancer
- IPv4: `10.7.11.31`
- Interface: `en0`
- Gateway: `10.7.0.1`
- Reverse proxy: `nginx`
- HTTP port: `8080/TCP` (redirects to HTTPS)
- HTTPS port: `8443/TCP` (TLS termination)
- Phase 2: `max_fails=3 fail_timeout=15s` on both backends (Extension D)

### Mac 3 — Krishiv

- Role: Backend A
- IPv4: `10.7.28.25`
- Interface: `en0`
- Gateway: `10.7.0.1`
- HTTP port: `3001`
- Phase 2: pf firewall — only Mac 2 (`10.7.11.31`) can reach port 3001 (Extension C)
- Phase 2: standby nginx on port 8443 (Extension E)

### Mac 4 — Vaidehi

- Role: Backend B + Client
- IPv4: `10.7.2.96`
- Interface: `en0`
- Gateway: `10.7.0.1`
- HTTP port: `3002`
- Phase 2: backup DNS server on port 53 (Extension A)

---

## 4. DNS

Domain: `team1.test`

Records:

```
app.team1.test → 10.7.11.31  (TTL 30s)
api.team1.test → 10.7.11.31  (TTL 30s)
```

Primary DNS: `10.7.10.8` (Mac 1 / Om)
Backup DNS: `10.7.2.96` (Mac 4 / Vaidehi — Extension A)

---

## 5. nginx (Primary Edge — Mac 2)

Public entry point: `https://app.team1.test:8443`

Listen:
- `8080` (HTTP → redirect to HTTPS)
- `8443` (HTTPS/TLS)

Upstream (Phase 2 Extension D):
```nginx
upstream backend_nodes {
    server 10.7.28.25:3001 max_fails=3 fail_timeout=15s;  # Backend A
    server 10.7.2.96:3002  max_fails=3 fail_timeout=15s;  # Backend B
}
```

Load balancing: Round-robin with passive health check

## 5b. nginx (Standby Edge — Mac 3 / Krishiv — Extension E)

Standby IP: `10.7.28.25:8443`
Config: `configs/nginx/nginx_standby.conf`
DNS cutover: change `app.team1.test` from `10.7.11.31` → `10.7.28.25`

---

## 6. Backend A

Host: `10.7.28.25`
Port: `3001`
Endpoints: `GET /` `GET /api/status`
Header: `X-Backend: A`
ETag: `"72db076608216f33"`
Firewall: only `10.7.11.31` (Mac 2) allowed on port 3001

---

## 7. Backend B

Host: `10.7.2.96`
Port: `3002`
Endpoints: `GET /` `GET /api/status`
Header: `X-Backend: B`
ETag: `"backend-b-v1"`

---

## 8. Phase 2 Extensions Summary

| Extension | Description | Owner | Status |
|---|---|---|---|
| A | Backup DNS resolver | Om | ✅ Done |
| B | DNS TTL = 30s | Om | ✅ Done |
| C | Backend A firewall isolation | Krishiv | ✅ Done |
| D | nginx HA failover (max_fails) | Aditya | ✅ Done |
| E | Standby nginx + DNS cutover | Om + Aditya | ✅ Done |
