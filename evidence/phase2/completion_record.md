# Extension C — Completion Record

## Phase 2 — Backend B Service Isolation (Mac 4)

| Item | Status | Evidence / Notes |
|------|--------|-----------------|
| Phase 1 baseline verified | ✅ | Backend B on TCP 3002, nginx on Mac 2, HTTPS on 8443 — all confirmed |
| Backend B confirmed on TCP 3002 | ✅ | `lsof -iTCP:3002`: Python PID 20356, binds `0.0.0.0:3002` |
| Backend B responds correctly | ✅ | `GET /api/status` → HTTP 200, `X-Backend: B`, `Cache-Control: max-age=60` |
| ETag / 304 verified | ✅ | `If-None-Match: "backend-b-v1"` → HTTP 304 from Backend B directly |
| Round-robin confirmed | ✅ | 6 requests → alternating A/B; see `live_test_results.md` |
| HTTPS end-to-end verified | ✅ | TLSv1.3, cert CN=app.team1.test matched, no `-k`; see `live_test_results.md` |
| Audit before-state captured | ✅ | `evidence/phase2/audit_before.md` — pf disabled, port 3002 unrestricted |
| pf anchor rules authored | ✅ | `evidence/phase2/pf_anchor.conf` |
| pf_setup.sh written and executable | ✅ | `evidence/phase2/pf_setup.sh` — idempotent, backs up /etc/pf.conf |
| pf_rollback.sh written and executable | ✅ | `evidence/phase2/pf_rollback.sh` — flushes anchor, restores backup |
| Loopback (127.0.0.1) preserved in rules | ✅ | `pass in quick on lo0 proto tcp to 127.0.0.1 port 3002` |
| Mac 2 (nginx) allowed on port 3002 | ✅ | `pass in quick on en0 proto tcp from 10.7.11.31 to any port 3002` |
| All other hosts blocked on port 3002 | ✅ | `block in quick on en0 proto tcp to any port 3002` |
| SSH / management access unaffected | ✅ | Rules are port-3002-specific only |
| Outbound traffic from Mac 4 unaffected | ✅ | Only inbound rules added |
| Backend A (Mac 3, port 3001) unaffected | ✅ | Rules only target Mac 4's port 3002 |
| Rules reversible | ✅ | `pf_rollback.sh` restores original `/etc/pf.conf` from backup |
| MAC2_IP confirmed | ✅ | `10.7.11.31` per `CN_PROJECT_LIVE_CONFIG.md`; ping from Mac 4 confirms reachable |
| Secrets not committed | ✅ | Only IPs and rules — no credentials |
| Existing config files not deleted | ✅ | `/etc/pf.conf` backed up before modification |
| Phase 2 doc created | ✅ | `docs/phase2.md` |
| Live test evidence saved | ✅ | `evidence/phase2/live_test_results.md` |

---

## Pending: Activation + Team Tests

The pf rules are **authored but not yet activated** (requires `sudo`). After confirming `MAC2_IP=10.7.11.31` with Aditya:

```bash
# Step 1 — Apply the firewall rules
sudo bash /Users/vaidehisahu/CN/evidence/phase2/pf_setup.sh

# Step 2 — Proof Point A: ask Aditya to run from Mac 2
curl http://10.7.2.96:3002/api/status
# Expected: HTTP 200, X-Backend: B

# Step 3 — Proof Point B: ask Om or Krishiv to run from Mac 1 or Mac 3
curl --connect-timeout 5 http://10.7.2.96:3002/
# Expected: Connection refused or timeout

# Step 4 — Proof Point C: HTTPS end-to-end (can run from any Mac)
curl --cacert /path/to/team1.test.crt https://app.team1.test:8443/api/status
# Expected: HTTP 200, TLS valid, X-Backend: A or B
```

Rollback at any time:
```bash
sudo bash /Users/vaidehisahu/CN/evidence/phase2/pf_rollback.sh
```

---

## Git
Branch: `p4-backend-b`
Committed: `2ce4510` (workflow) + live test results (pending commit)
