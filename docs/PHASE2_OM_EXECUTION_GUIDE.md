# Phase 2 — Om's Implementation & Viva Guide
**Role:** Mac 1 — Private DNS + Client | **Primary IP:** `10.7.10.8`

---

## 1. Phase 1 Baseline Verification Summary: ✅ PASSED

All required Phase 1 checks were audited and passed live:
1. **Host Identity & LAN**: Active interface `en0`, IP `10.7.10.8` (updated from historical `10.7.15.236`), subnet `10.7.0.0/19`, gateway `10.7.0.1`.
2. **Primary DNS**: `dnsmasq` running on `10.7.10.8:53`, correctly resolving `app.team1.test` -> `10.7.11.31`.
3. **Backend A**: Running on Krishiv's Mac (`10.7.28.25:3001`), returning `X-Backend: A`.
4. **Backend B**: Running on Vaidehi's Mac (`10.7.2.96:3002`), returning `X-Backend: B`.
5. **Nginx Edge**: Running on Aditya's Mac (`10.7.11.31:8443`), TLS 1.3 active with cipher `TLS_AES_256_GCM_SHA384`.
6. **Round-Robin Load Balancing**: Alternates traffic between A and B (`A -> B -> A -> B`).
7. **HTTP Caching**: `Cache-Control: max-age=60`, `ETag: "backend-b-v1"`, and 304 revalidation verified.
8. **Wireshark PCAPs & Failure Modes**: Documented in `evidence/wireshark/` and `docs/script8_completion_report.md`.

---

## 2. Phase 2 Responsibilities Breakdown

### Extension A: Backup DNS Resolver
* **Objective:** Ensure DNS remains available even if Mac 1's primary DNS crashes.
* **Secondary Host:** Choose Mac 4 (Vaidehi / `10.7.2.96`) or Mac 3 (Krishiv / `10.7.28.25`).
* **Secondary Configuration (`dnsmasq_secondary.conf`):**
  ```conf
  port=53
  listen-address=127.0.0.1,<SECONDARY_MAC_IP>
  bind-interfaces
  local-ttl=30
  address=/app.team1.test/10.7.11.31
  address=/api.team1.test/10.7.11.31
  ```
* **Failover Proof:**
  1. Client sets DNS servers: `10.7.10.8` (Primary) and `<SECONDARY_MAC_IP>` (Backup).
  2. Kill primary DNS on Mac 1: `sudo killall dnsmasq`.
  3. Client runs: `dig app.team1.test`.
  4. Output shows `SERVER: <SECONDARY_MAC_IP>#53` answering.
  5. Restart primary DNS on Mac 1.

---

### Extension B: DNS TTL (30 Seconds)
* **Configuration:** Added `local-ttl=30` to `config/dnsmasq.conf`.
* **Restart dnsmasq:**
  ```bash
  sudo killall dnsmasq && sudo /opt/homebrew/sbin/dnsmasq -C /Users/tanish/Om_Kar_CN_Project/CN_Project/config/dnsmasq.conf
  ```
* **Verification Command:**
  ```bash
  dig app.team1.test @10.7.10.8
  ```
  Answer section displays:
  ```
  app.team1.test.    30    IN    A    10.7.11.31
  ```
* **Demonstration of Cache & Expiry:**
  - Client queries record. Resolver caches it for 30 seconds.
  - Change IP in `dnsmasq.conf` to a test IP.
  - Client queries again immediately: old answer persists from local cache.
  - Wait 30 seconds (or flush `sudo dscacheutil -flushcache`): new IP appears.

---

### Extension E Support: Edge Migration
* **Objective:** Smooth migration from Primary Edge (`10.7.11.31`) to Standby Edge IP.
* **Procedure:**
  1. Coordinate with Aditya: wait until he confirms standby Nginx edge is active and tested.
  2. Edit `config/dnsmasq.conf`:
     ```conf
     address=/app.team1.test/<STANDBY_EDGE_IP>
     ```
  3. Restart dnsmasq.
  4. Because TTL is 30 seconds, clients seamlessly cut over to the standby edge within 30 seconds.
  5. Rollback: change address back to `10.7.11.31` and restart dnsmasq.

---

## 3. How to Explain in Viva

* **Primary vs. Backup DNS:**
  "Primary DNS is the designated authoritative resolver for the private `.test` zone. If the primary host goes down or suffers network partition, the client's resolver stack falls back to the secondary DNS IP, ensuring uninterrupted name resolution."
* **TTL & Caching:**
  "TTL defines how long recursive resolvers and client OS caches retain a DNS answer before re-querying the authoritative server. A short 30-second TTL allows rapid cutover during migrations, though existing connections and client caches persist until expiry."
* **Edge Migration:**
  "We leverage DNS-level redirection. When migrating to standby edge, we update the A record in dnsmasq. Clients switch over automatically once their short 30s TTL expires, with zero reconfiguration required on client applications."
