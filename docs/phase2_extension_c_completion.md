# Phase 2 Extension C — Backend A Service Isolation
## Mac 3 | Krishiv

---

## Summary
Configured a reversible macOS `pf` firewall policy on Mac 3 (Backend A) that:
- **Allows** Mac 2 (Aditya nginx, `10.7.11.31`) to reach Backend A on TCP 3001
- **Allows** localhost (`127.0.0.1`) for local health checks and management
- **Blocks** all other direct inbound connections to TCP 3001 on `en0`
- Public HTTPS application continues to work via nginx on Mac 2

---

## Phase 1 Baseline (verified before Phase 2)

| Item | Value |
|---|---|
| Mac 3 IP | `10.7.28.25` on `en0` |
| Subnet | `10.7.0.0/19`, mask `255.255.224.0` |
| Gateway | `10.7.0.1` |
| Backend A port | TCP 3001, listening on `0.0.0.0` |
| `GET /api/status` | `{"backend":"A","status":"ok"}` |
| `X-Backend` header | `A` |
| Mac 2 (nginx) IP | `10.7.11.31` |
| Mac 4 (Backend B) IP | `10.7.2.96` |
| Mac 1 (DNS) IP | `10.7.10.8` |
| DNS resolution | `app.team1.test` → `10.7.11.31` ✅ |
| Ping all nodes | ✅ |
| nginx round-robin | A↔B alternating ✅ |

---

## Implementation

### Anchor file: `/etc/pf.anchors/backend_a_isolation`
```
# Backend A Service Isolation — Phase 2 Extension C
# Allow Mac 2 (Aditya nginx) — quick exits immediately on match
pass in quick on en0 proto tcp from 10.7.11.31 to any port 3001
# Allow localhost — quick exits immediately on match
pass in quick on lo0 proto tcp from 127.0.0.1 to any port 3001
# Block all other direct access to TCP 3001
block in on en0 proto tcp from any to any port 3001
```
> Note: `quick` is required on pass rules — without it pf's last-match-wins logic causes the block at the bottom to override the pass for Aditya.

### Addition to `/etc/pf.conf`:
```
# Phase 2 Extension C — Backend A service isolation
anchor "backend_a_isolation"
load anchor "backend_a_isolation" from "/etc/pf.anchors/backend_a_isolation"
```

### Command to load rules:
```bash
sudo pfctl -f /etc/pf.conf
```

---

## Verification Results

| Test | Command | Result |
|---|---|---|
| Localhost → Backend A | `curl http://127.0.0.1:3001/api/status` | ✅ `{"backend":"A","status":"ok"}` |
| Public HTTPS via nginx | `curl -sk https://10.7.11.31:8443/api/status` | ✅ `200 OK` |
| Active pf rules | `sudo pfctl -a backend_a_isolation -s rules` | ✅ 3 rules loaded |
| Direct block (unauthorized) | Mac 4 direct TCP 3001 | ❌ blocked (pf drop) |

---

## Rollback Steps
To fully remove the isolation rules:

```bash
# 1. Remove the anchor from pf.conf
sudo cp /etc/pf.conf.backup_phase2 /etc/pf.conf

# 2. Remove the anchor file
sudo rm /etc/pf.anchors/backend_a_isolation

# 3. Reload pf
sudo pfctl -f /etc/pf.conf
```

Backup of original pf.conf: `/etc/pf.conf.backup_phase2`
Before rules: `evidence/phase2_pf_before.txt`
After rules: `evidence/phase2_pf_after.txt`

---

## Completion Record

| Item | Status | Evidence |
|---|---|---|
| Phase 1 baseline verified | ✅ DONE | IPs confirmed, all pings OK, DNS resolves, round-robin verified |
| Phase 2 implementation applied | ✅ DONE | `/etc/pf.anchors/backend_a_isolation` loaded via `/etc/pf.conf` |
| Mac 2 (Aditya) direct → Backend A | ✅ DONE | `curl http://10.7.28.25:3001/api/status` → `{"backend":"A","status":"ok"}` (after adding `quick` to pass rules) |
| Public HTTPS works | ✅ DONE | `curl -sk https://10.7.11.31:8443/api/status` → 200 |
| Unauthorized direct access blocked | ✅ DONE | Mac 4 (Vaidehi, `10.7.2.96`) `curl http://10.7.28.25:3001` → timeout after 2008ms (pf drop confirmed) |
| Rollback documented | ✅ DONE | See rollback steps above |

---

## Handoff Notes
- Backend A: `10.7.28.25:3001`, listens on `0.0.0.0`
- Edge allowed: Mac 2 nginx (`10.7.11.31`) only
- Direct access denied: all other hosts on `en0` (including Mac 4 `10.7.2.96`)
- Application works end-to-end via `https://app.team1.test:8443`
- Limitation: rule is IP-based; if Mac 2's IP changes, update the anchor file and reload pf
