# Phase 2 — Completion Report
> Om (Mac 1) | Private DNS + Client | Phase 2 Extensions A, B, E-support

---

## Status Summary

| Extension | Description | Config Status | Script Status | Evidence |
|-----------|-------------|---------------|---------------|----------|
| **A** | Backup DNS Resolver | `config/dnsmasq_secondary.conf` ✅ | `scripts/phase2_backup_dns.sh` ✅ / `scripts/backup_dns_server.py` ✅ | ✅ `evidence/phase2/extension_a/` — live failover tested |
| **B** | DNS TTL = 30s | `local-ttl=30` in `config/dnsmasq.conf` ✅ | `scripts/phase2_test_ttl.sh` ✅ | ✅ `evidence/phase2/extension_b/` — cache cutover tested |
| **E-support** | Edge migration DNS cutover | `config/dnsmasq.conf` updated live ✅ | Cutover + rollback executed ✅ | ✅ `evidence/phase2/extension_e/` — live migration tested |

## Live Test Results

### Extension A — Backup DNS Failover (tested Mon 23 Nov 2026)
- **Backup resolver used:** Mac 3 / Krishiv (`10.7.28.25`) — dnsmasq already running with correct records
- **Primary killed:** `sudo killall dnsmasq` → `pgrep` confirmed no process
- **Backup answered:** `dig app.team1.test @10.7.28.25` → `10.7.11.31` with `SERVER: 10.7.28.25#53` ✅
- **Primary restored:** `sudo /opt/homebrew/sbin/dnsmasq -C config/dnsmasq.conf` ✅
- Evidence files: `01_primary_resolves.txt`, `02_backup_resolves.txt`, `03_failover_proof.txt`, `04_primary_restored.txt`

### Extension E — Edge Migration DNS Cutover (tested Mon 23 Nov 2026)
- **Standby edge:** Mac 3 / Krishiv (`10.7.28.25:8443`) — nginx_standby.conf deployed with same backends
- **Pre-cutover:** `app.team1.test → 10.7.11.31`, curl returned `{"backend":"B","status":"ok"}` ✅
- **DNS switched** to `10.7.28.25`, dnsmasq restarted — `dig @10.7.10.8` immediately returned `10.7.28.25` ✅
- **curl via domain** hit standby edge: `{"backend":"A","status":"ok"}` ✅
- **TTL cache effect** demonstrated: stale system resolver queried public DNS (NXDOMAIN — proves `.test` is private), authoritative returned new IP ✅
- **After 32s + cache flush:** `app.team1.test → 10.7.28.25` confirmed ✅
- **Rollback:** record restored to `10.7.11.31`, curl via domain confirmed primary edge back ✅
- Evidence files: `01_pre_cutover.txt`, `02_post_cutover.txt`, `03_ttl_cache_effect.txt`, `04_rollback.txt`
- **Baseline:** `app.team1.test 30 IN A 10.7.11.31` — TTL confirmed 30s ✅
- **Record changed** to `10.7.11.99` (simulated standby edge), dnsmasq restarted
- **Immediate query:** authoritative returned `10.7.11.99` instantly ✅
- **After 32s + cache flush:** `10.7.11.99` confirmed from fresh query ✅
- **Rollback:** record restored to `10.7.11.31`, verified ✅
- Evidence files: `01_ttl_baseline.txt`, `02_immediately_after_change.txt`, `03_after_ttl_expiry.txt`, `04_rollback.txt`

---

## Extension A — Backup DNS Resolver

### What was built

A secondary dnsmasq configuration (`config/dnsmasq_secondary.conf`) that serves the same
`app.team1.test` and `api.team1.test` A records as the primary, with the same 30-second TTL.

It is designed to run on Mac 4 (Vaidehi / `10.7.2.96`) or Mac 3 (Krishiv / `10.7.28.25`).

A pure-Python fallback server (`scripts/backup_dns_server.py`) is also provided.
It uses only the Python standard library so it runs anywhere Python 3 is available,
without installing dnsmasq on the secondary host.

### Configuration (`config/dnsmasq_secondary.conf`)

```
port=53
listen-address=127.0.0.1,10.7.2.96
bind-interfaces
local-ttl=30
address=/app.team1.test/10.7.11.31
address=/api.team1.test/10.7.11.31
```

### How to start the backup DNS on Mac 4 (Vaidehi)

```zsh
# Option 1: dnsmasq (if installed on Mac 4)
sudo /opt/homebrew/sbin/dnsmasq -C /path/to/CN_Project/config/dnsmasq_secondary.conf

# Option 2: Python server (no dnsmasq required on Mac 4)
sudo python3 /path/to/CN_Project/scripts/backup_dns_server.py 10.7.11.31
```

### Failover test procedure

```zsh
# Step 1: Confirm primary DNS responds
dig app.team1.test @10.7.10.8 +short
# Expected: 10.7.11.31

# Step 2: Confirm backup DNS responds
dig app.team1.test @10.7.2.96 +short
# Expected: 10.7.11.31

# Step 3: Simulate primary DNS failure (run on Mac 1)
sudo killall dnsmasq
pgrep -fl dnsmasq  # should return nothing

# Step 4: Prove failover — query backup directly
dig app.team1.test @10.7.2.96
# Key line in output: ;; SERVER: 10.7.2.96#53(10.7.2.96)
# Answer section must still show 10.7.11.31

# Step 5: Restore primary DNS on Mac 1
sudo /opt/homebrew/sbin/dnsmasq -C /Users/tanish/Om_Kar_CN_Project/CN_Project/config/dnsmasq.conf

# Step 6: Confirm primary is back
dig app.team1.test @10.7.10.8 +short
# Expected: 10.7.11.31
```

### Viva explanation

> "Primary DNS and backup DNS both serve identical records for app.team1.test and api.team1.test,
> both with a 30-second TTL. When a client configures both resolvers — the primary at 10.7.10.8
> and the backup at 10.7.2.96 — the OS tries the primary first. If the primary is unreachable or
> fails to respond within the timeout, the resolver stack automatically retries the query against
> the secondary. This is not load-sharing; the backup only receives queries when the primary is
> unavailable. I prove this by stopping dnsmasq on Mac 1 and showing that a direct query to
> the backup IP still returns the correct answer."

---

## Extension B — DNS TTL (30 seconds)

### What was configured

`config/dnsmasq.conf` contains:
```
local-ttl=30
```

This sets the TTL field in every DNS answer to 30 seconds. Clients and resolvers that cache DNS
responses will re-query after 30 seconds at most.

### Verification command

```zsh
dig app.team1.test @10.7.10.8
```

Expected answer section:
```
app.team1.test.    30    IN    A    10.7.11.31
```

The `30` in the second column is the TTL.

### Cache cutover demonstration

```zsh
# 1. Query — observe TTL = 30
dig app.team1.test @10.7.10.8

# 2. Change the record to a standby IP to simulate migration
#    Edit config/dnsmasq.conf: address=/app.team1.test/10.7.11.99
#    Then restart dnsmasq:
sudo killall dnsmasq
sudo /opt/homebrew/sbin/dnsmasq -C /Users/tanish/Om_Kar_CN_Project/CN_Project/config/dnsmasq.conf

# 3. Query immediately — if system resolver cached the old answer, it still returns 10.7.11.31
dig app.team1.test  # (uses OS cache, may show stale answer)

# 4. Wait 30 seconds OR flush the macOS DNS cache explicitly:
sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder

# 5. Query again — now resolves to new IP
dig app.team1.test @10.7.10.8
# Expected: 10.7.11.99

# 6. Rollback
#    Edit config/dnsmasq.conf back to address=/app.team1.test/10.7.11.31
#    Then restart dnsmasq.
```

### Viva explanation

> "TTL — Time To Live — is a field in every DNS answer record that tells caching resolvers and
> client OS caches how long to hold the answer before discarding it and re-querying. We set it
> to 30 seconds. If I change the IP in dnsmasq and restart the service, a client that cached the
> old answer up to 30 seconds ago will still reach the old IP until its cache entry expires.
> After 30 seconds — or after a manual flush with dscacheutil — it re-queries and gets the new IP.
> This is exactly the trade-off in production DNS changes: a shorter TTL means faster convergence
> after a change, but more query traffic to the authoritative server."

---

## Extension E Support — Edge Migration DNS Cutover

### Procedure (coordinate with Aditya)

```zsh
# Step 1: Confirm Aditya's standby nginx is live and tested
#         Do NOT change the DNS record until Aditya confirms.

# Step 2: Edit config/dnsmasq.conf on Mac 1
#         Change: address=/app.team1.test/10.7.11.31
#         To:     address=/app.team1.test/<STANDBY_EDGE_IP>

# Step 3: Restart dnsmasq
sudo killall dnsmasq
sudo /opt/homebrew/sbin/dnsmasq -C /Users/tanish/Om_Kar_CN_Project/CN_Project/config/dnsmasq.conf

# Step 4: Verify new record
dig app.team1.test @10.7.10.8 +short
# Expected: <STANDBY_EDGE_IP>

# Step 5: Client (Mac 4) flushes cache and verifies
sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder
dig app.team1.test +short
curl -s https://app.team1.test:8443/api/status

# Step 6: Rollback if needed
#         Change address back to 10.7.11.31 and restart dnsmasq.
```

### Viva explanation

> "Edge migration with DNS-based cutover works because we control the authoritative DNS record
> for app.team1.test. When Aditya's standby nginx is ready, I update the A record to point to
> the standby IP and restart dnsmasq. Because TTL is 30 seconds, all clients switch over within
> 30 seconds of their cached entry expiring. No client reconfiguration is needed. The rollback
> is symmetric: change the record back and restart dnsmasq."

---

## Files Created / Modified

| File | Change | Purpose |
|------|--------|---------|
| `config/dnsmasq.conf` | Added `local-ttl=30` | Extension B: 30-second TTL |
| `config/dnsmasq_secondary.conf` | Created | Extension A: backup DNS config |
| `scripts/backup_dns_server.py` | Created (fixed) | Extension A: stdlib-only backup DNS |
| `scripts/phase2_backup_dns.sh` | Created | Extension A: failover test script |
| `scripts/phase2_test_ttl.sh` | Created | Extension B: TTL verification script |
| `docs/PHASE2_OM_EXECUTION_GUIDE.md` | Created | Full guide + viva prep |
| `evidence/phase2/extension_a/` | Created | Evidence directory for Extension A |
| `evidence/phase2/extension_b/` | Created | Evidence directory for Extension B |

---

## Pre-Demo Checklist

- [ ] dnsmasq running on Mac 1: `pgrep -fl dnsmasq`
- [ ] Primary DNS resolves correctly: `dig app.team1.test @10.7.10.8 +short` → `10.7.11.31`
- [ ] TTL is 30: `dig app.team1.test @10.7.10.8` → `30 IN A 10.7.11.31`
- [ ] Backup DNS running on secondary host: `dig app.team1.test @10.7.2.96 +short` → `10.7.11.31`
- [ ] Failover tested: kill primary, backup still answers
- [ ] Primary restored: `pgrep -fl dnsmasq` shows running process

---

## Handoff Values

| Item | Value |
|------|-------|
| Primary DNS IP | `10.7.10.8` |
| Backup DNS IP | `10.7.2.96` (Mac 4 / Vaidehi) |
| Records served | `app.team1.test → 10.7.11.31`, `api.team1.test → 10.7.11.31` |
| TTL | 30 seconds |
| Primary config | `config/dnsmasq.conf` |
| Secondary config | `config/dnsmasq_secondary.conf` |
| Failover script | `scripts/phase2_backup_dns.sh` |
| Python backup server | `scripts/backup_dns_server.py` |
| Restart primary | `sudo killall dnsmasq && sudo /opt/homebrew/sbin/dnsmasq -C /Users/tanish/Om_Kar_CN_Project/CN_Project/config/dnsmasq.conf` |
| Rollback record | `address=/app.team1.test/10.7.11.31` |
| Client cache flush | `sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder` |
