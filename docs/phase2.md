# Phase 2 — Extension C: Backend B Service Isolation

## Issue
Backend B (Node.js/Python, TCP 3002) on Mac 4 (`10.7.2.96`) was accessible to any host on the
`10.7.0.0/19` LAN. The assignment requires that only Mac 2 (nginx proxy, `10.7.11.31`) can
reach port 3002 directly. All other direct inbound connections must be blocked.

## Change Made
A macOS `pf` (Packet Filter) anchor named `com.cn-project.backend-b-isolation` was designed
and all artifacts written to `/Users/vaidehisahu/CN/evidence/phase2/`.

### Rules (in order)
1. **PASS** — loopback (`lo0`) → `127.0.0.1:3002` (preserves localhost access)
2. **PASS** — `en0`, source `10.7.11.31` (Mac 2 nginx) → any:3002
3. **BLOCK** — `en0`, any source → any:3002

Outbound traffic, SSH, and all other ports are **not touched** by these rules.

## Activation
```bash
# Confirm MAC2_IP=10.7.11.31 with Aditya first
sudo bash /Users/vaidehisahu/CN/evidence/phase2/pf_setup.sh
```

## Rollback
```bash
sudo bash /Users/vaidehisahu/CN/evidence/phase2/pf_rollback.sh
```
This flushes the anchor, removes the anchor rules file, and restores `/etc/pf.conf`
from the backup created by `pf_setup.sh`.

## Artifacts

| File | Purpose |
|------|--------|
| `evidence/phase2/audit_before.md` | Pre-change system state |
| `evidence/phase2/pf_anchor.conf` | pf anchor rules (reference copy) |
| `evidence/phase2/pf_setup.sh` | Idempotent activation script |
| `evidence/phase2/pf_rollback.sh` | Full rollback script |
| `evidence/phase2/verification_plan.md` | Exact test commands |
| `evidence/phase2/completion_record.md` | Completion table |

## Live Tests (Pre-Activation)

Tested from Mac 4 before pf rules were activated — see `evidence/phase2/live_test_results.md`.

| Test | Result |
|------|--------|
| Backend B loopback (`127.0.0.1:3002`) | ✅ HTTP 200, X-Backend: B |
| ETag `"backend-b-v1"` / 304 Not Modified | ✅ Confirmed |
| HTTPS `app.team1.test:8443` via nginx | ✅ TLSv1.3, cert validated, HTTP 200 |
| Round-robin (6 requests) | ✅ Alternating A/B, Cache-Control: max-age=60 on all |
| Mac 2 ping from Mac 4 | ✅ 0% packet loss, MAC2_IP=10.7.11.31 confirmed |

## Verification After Activation

See `evidence/phase2/verification_plan.md` for exact commands proving:
- (A) Mac 2 (`10.7.11.31`) can reach port 3002 — run by Aditya
- (B) Unauthorized host (Mac 1 or Mac 3) is blocked on port 3002 — run by Om or Krishiv
- (C) `https://app.team1.test:8443` HTTPS still works end-to-end
