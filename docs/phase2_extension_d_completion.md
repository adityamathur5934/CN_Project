# Phase 2 Extension D — Backend HA Failover
## Mac 2 | Aditya | nginx upstream passive health check

---

## Status: ✅ COMPLETE

---

## What Was Built

Configured nginx upstream passive failure handling using `max_fails` and `fail_timeout`
on each backend server. When a backend fails to respond `max_fails` times within
`fail_timeout` seconds, nginx marks it unavailable and stops sending requests to it.
After `fail_timeout` seconds, nginx tries it again automatically.

This is **passive health checking** — nginx detects failures only when real client
requests fail, not by sending dedicated probe requests. Open-source nginx does not
support active health checks (that is an nginx Plus feature).

---

## Configuration Change

**File:** `/opt/homebrew/etc/nginx/servers/team.conf`
**Repo copy:** `configs/nginx/nginx_https.conf`

```nginx
upstream backend_nodes {
    server 10.7.28.25:3001 max_fails=3 fail_timeout=15s;  # Backend A — Mac 3 (Krishiv)
    server 10.7.2.96:3002  max_fails=3 fail_timeout=15s;  # Backend B — Mac 4 (Vaidehi)
}
```

**What max_fails=3 means:** After 3 consecutive failed connection attempts to a backend,
nginx marks it as unavailable.

**What fail_timeout=15s means:** The backend stays marked unavailable for 15 seconds,
then nginx tries it again. If it responds, it re-enters the pool.

**proxy_connect_timeout=5s** means each failed attempt registers within 5 seconds,
so a full 3-fail detection takes at most 15 seconds.

---

## Phase 1 Baseline (verified before Phase 2)

| Item | Value |
|---|---|
| Mac 2 IP | `10.7.11.31` on `en0` |
| Mac 3 (Backend A) | `10.7.28.25:3001` |
| Mac 4 (Backend B) | `10.7.2.96:3002` |
| nginx status | Running, ports 8080 + 8443 active |
| nginx config test | PASS |
| Round-robin baseline | A↔B alternating — confirmed |
| HTTPS without -k | Confirmed working |

---

## Failover Test Results

### Step 1 — Baseline (both backends running)
```
Request 1: {"backend": "A", "status": "ok"}
Request 2: {"backend": "B", "status": "ok"}
Request 3: {"backend": "A", "status": "ok"}
Request 4: {"backend": "B", "status": "ok"}
```
Both backends serving. Round-robin confirmed.

### Step 2 — Failover (Backend A stopped on Mac 3)
```
Request 1: {"backend": "B", "status": "ok"}
Request 2: {"backend": "B", "status": "ok"}
Request 3: {"backend": "B", "status": "ok"}
Request 4: {"backend": "B", "status": "ok"}
Request 5: {"backend": "B", "status": "ok"}
Request 6: {"backend": "B", "status": "ok"}
```
All 6 requests served by Backend B only. Service never interrupted.
nginx detected Backend A as unavailable and routed all traffic to Backend B.

### Step 3 — Recovery (Backend A restarted on Mac 3)
```
Request 1: {"backend": "B", "status": "ok"}
Request 2: {"backend": "A", "status": "ok"}
Request 3: {"backend": "B", "status": "ok"}
Request 4: {"backend": "A", "status": "ok"}
Request 5: {"backend": "B", "status": "ok"}
Request 6: {"backend": "A", "status": "ok"}
```
Round-robin A↔B fully resumed. Automatic recovery — no nginx restart needed.

**Evidence file:** `evidence/phase2/extension_d/failover_test.txt`

---

## Remaining Single Point of Failure

nginx on Mac 2 is still a single point of failure. If Mac 2 goes down:
- DNS resolves `app.team1.test` to `10.7.11.31` correctly
- But TCP connections to port 8443 fail — no edge to receive them
- Both backends may be healthy but unreachable

**Extension E (standby nginx + DNS cutover) addresses this.**

---

## Completion Record

| Item | Status | Evidence |
|---|---|---|
| Phase 1 baseline verified | ✅ DONE | Both backends, HTTPS, round-robin confirmed |
| max_fails/fail_timeout configured | ✅ DONE | `upstream backend_nodes` in team.conf |
| nginx config test passed | ✅ DONE | `nginx -t` passed |
| nginx reloaded | ✅ DONE | `nginx -s reload` |
| Failover demonstrated | ✅ DONE | 6/6 requests → Backend B when A stopped |
| Recovery demonstrated | ✅ DONE | Round-robin resumed after Backend A restart |
| Evidence saved | ✅ DONE | `evidence/phase2/extension_d/failover_test.txt` |
| Single point of failure identified | ✅ DONE | nginx Mac 2 — addressed by Extension E |

---

## Viva Explanation

> "Extension D adds passive health checking to our nginx upstream. I configured max_fails=3
> and fail_timeout=15s on both backend servers. When Backend A fails to respond 3 times,
> nginx marks it unavailable for 15 seconds and routes all traffic to Backend B. When Backend A
> comes back, nginx automatically re-adds it to the pool and round-robin resumes. This is
> passive health checking — nginx only detects failures on real requests. Active health checking,
> which probes backends independently, is an nginx Plus feature not available in open-source nginx."

---

## Handoff Notes

- nginx upstream config: `max_fails=3 fail_timeout=15s` on both servers
- Config file: `/opt/homebrew/etc/nginx/servers/team.conf`
- Repo copy: `configs/nginx/nginx_https.conf`
- Evidence: `evidence/phase2/extension_d/failover_test.txt`
- Rollback: remove `max_fails` and `fail_timeout` params, run `nginx -s reload`
- Coordination with Krishiv: Backend A firewall (Extension C) allows Mac 2 at `10.7.11.31`
- If Mac 2 IP changes: update pf anchor on Mac 3 AND nginx upstream config
