# CN Project — Private Network Service Platform
> Computer Networks Course Project | P2 (Mac 2) — Edge / nginx

---

## Project Overview

Build a fully local Private Network Service Platform using 4 macOS laptops on the same private Wi-Fi/LAN.
The application stays simple — **the network is the project**.

```
Client → DNS (Mac 1) → HTTPS Edge/nginx (Mac 2) → Backend A (Mac 3) or Backend B (Mac 4)
```

**No cloud hosting. Everything runs locally on LAN 10.7.0.0/19.**

---

## Team & Roles

| Person | Machine | Role | IP |
|--------|---------|------|----|
| P1 | Mac 1 | Private DNS Server (dnsmasq) + Test Client | [P1_IP] |
| **P2 (YOU)** | **Mac 2** | **Edge / nginx / TLS / Load Balancer** | **10.7.17.151** |
| P3 | Mac 3 | Backend A — REST API :3001 | [P3_IP] |
| P4 | Mac 4 | Backend B + Test Client — REST API :3002 | [P4_IP] |

**Private Domain:** `app.team.test` → resolves to Mac 2 (10.7.17.151)

---

## Project Structure

```
CN_Project/
├── README.md                        ← This file
│
├── docs/
│   ├── lan_inventory.md             ← IP/service inventory for all machines
│   ├── topology.md                  ← Network diagram + request flow + layer mapping
│   ├── script0_completion_report.md ← Script 0 done conditions & P2 network state
│   └── architecture.md              ← [TODO] Full architecture document (deliverable)
│
├── configs/
│   ├── nginx/
│   │   ├── nginx.conf.bak           ← Backup before any modification
│   │   ├── nginx_http.conf          ← Script 4: HTTP reverse proxy + load balancer
│   │   └── nginx_https.conf         ← Script 5: HTTPS/TLS config
│   └── tls/
│       ├── README.md                ← Certificate creation instructions
│       ├── team.test.crt            ← Self-signed certificate (Script 5)
│       └── team.test.key            ← Private key (Script 5)
│
├── scripts/
│   ├── verify_lan.sh                ← Script 0: Pairwise ping check
│   ├── test_backends.sh             ← Script 4: Verify nginx reaches both backends
│   ├── test_loadbalancer.sh         ← Script 4: Hit endpoint repeatedly, observe A/B
│   └── test_https.sh                ← Script 5: Full HTTPS verification
│
├── evidence/
│   ├── script0/                     ← LAN setup screenshots / ping output
│   ├── script4/                     ← HTTP load balancer curl output
│   ├── script5/                     ← HTTPS curl output, cert info
│   ├── wireshark/                   ← .pcap files + annotated screenshots
│   └── failures/                    ← Phase 1 failure test output
│
└── index.py                         ← (Original placeholder)
```

---

## Build Sequence (P2 Perspective)

| Stage | Script | Action | Depends On |
|-------|--------|--------|------------|
| ✅ | Script 0 | LAN setup — Mac 2 network confirmed | — |
| ⏳ | — | Wait for P1 DNS checkpoint | P1 |
| ⏳ | — | Receive P3 + P4 IP:port details | P3, P4 |
| ⏳ | Script 4 | Install nginx, reverse proxy, load balancer | P3 + P4 done |
| ⏳ | Script 5 | Add HTTPS / TLS termination | Script 4 done |
| ⏳ | Script 7 | Wireshark evidence capture | Script 5 done |
| ⏳ | Script 8 | Phase 1 failure tests | Script 7 done |
| ⏳ | Script 11 | Backend failover config | Phase 2 start |
| ⏳ | Script 12 | Standby edge + DNS migration | P1 Phase 2 done |

---

## Key Commands Reference (P2)

### Network inspection
```bash
ifconfig en0                          # Your IP and interface info
netstat -rn | grep "^default"        # Default gateway
arp -n <IP>                          # Check ARP reachability
ping -c 3 <IP>                       # Reachability test
```

### nginx (after Script 4)
```bash
brew services start nginx            # Start nginx
brew services stop nginx             # Stop nginx
brew services restart nginx          # Restart nginx
nginx -t                             # Test configuration syntax
nginx -T                             # Dump full resolved config
tail -f /usr/local/var/log/nginx/access.log   # Watch access logs
tail -f /usr/local/var/log/nginx/error.log    # Watch error logs
```

### Backend connectivity (after P3/P4 are up)
```bash
curl http://[P3_IP]:3001/api/status  # Test Backend A directly
curl http://[P4_IP]:3002/api/status  # Test Backend B directly
curl -I http://app.team.test/api/status        # Test via nginx (HTTP)
curl -I https://app.team.test/api/status       # Test via nginx (HTTPS)
```

### Load balancing verification
```bash
for i in {1..6}; do curl -s https://app.team.test/api/status | grep backend; done
# Should alternate: "A", "B", "A", "B", "A", "B"
```

### TLS certificate info
```bash
openssl s_client -connect app.team.test:443 -showcerts
curl -v https://app.team.test/ 2>&1 | grep -E "SSL|TLS|cert"
```

---

## Shared Agent Rules (reference)

These rules apply whenever using an AI agent for this project:

1. Inspect current machine/network state before making changes
2. Never invent IP addresses — use only confirmed values
3. Back up configuration before modifying it
4. Prefer reversible changes
5. Do not modify another teammate's component unless instructed
6. Test every change — do not assume it works
7. Document: configuration, commands, expected output, troubleshooting
8. Stop at the requested checkpoint — do not advance into the next phase
9. At the end of each task: run tests, state what works, list assumptions,
   list values the next teammate needs

---

## Values This Machine Provides to Teammates

| Value | Who Needs It | When |
|-------|-------------|------|
| Mac 2 IP: `10.7.17.151` | P1 (for DNS A record) | Before Script 1 |
| HTTPS endpoint: `https://app.team.test` | P3, P4 (for integration test) | After Script 5 |
| nginx load balancer status | Everyone (Phase 1 checkpoint) | After Script 4 |

---

## Values This Machine Needs from Teammates

| Value | From | Needed For | When |
|-------|------|-----------|------|
| P1's IP address | P1 | DNS checkpoint verification | Script 4 |
| P3's IP address | P3 | nginx upstream `[P3_IP]:3001` | Script 4 |
| P4's IP address | P4 | nginx upstream `[P4_IP]:3002` | Script 4 |
| Agreed `.test` domain | Team | `server_name` in nginx config | Script 4 |

---

## Deliverables Checklist

| Deliverable | Status | Location |
|-------------|--------|----------|
| Architecture Document | ⏳ In progress | docs/architecture.md |
| Network Topology | ✅ Done | docs/topology.md |
| LAN Inventory | ✅ Done | docs/lan_inventory.md |
| nginx HTTP config | ⏳ Script 4 | configs/nginx/nginx_http.conf |
| nginx HTTPS config | ⏳ Script 5 | configs/nginx/nginx_https.conf |
| TLS certificate + key | ⏳ Script 5 | configs/tls/ |
| Wireshark evidence | ⏳ Script 7 | evidence/wireshark/ |
| Failure test output | ⏳ Script 8 | evidence/failures/ |
| Phase 2 failover config | ⏳ Phase 2 | configs/nginx/ |
