# Script 7 — Wireshark Evidence Capture
## Completion Report

**Project:** CN_Project — Private Network Service Platform
**Machine:** Mac 2 — Aditya (Edge / nginx / TLS / Load Balancer)
**Date:** [FILL: date of capture]
**Capture file:** `evidence/script7/pcap/[FILL: filename].pcapng`

---

## 1. Objective

Capture and document one complete end-to-end request cycle through the full Phase 1 path:

```
Client → DNS (Mac 1) → HTTPS/nginx (Mac 2) → Backend A or B (Mac 3 / Mac 4)
```

URL used: `https://app.team1.test`

---

## 2. Network Addresses (Live Config)

| Role | Machine | IP | Port |
|------|---------|-----|------|
| DNS Server | Mac 1 — Om | 10.7.15.236 | 53/UDP |
| Edge / nginx | Mac 2 — Aditya | 10.7.17.151 | 443/TCP |
| Backend A | Mac 3 — Krishiv | 10.7.10.0 | 3001/TCP |
| Backend B | Mac 4 — Vaidehi | 10.7.16.36 | 3002/TCP |
| Test Client | Mac 2 / Mac 4 | — | ephemeral |

---

## 3. Capture Setup

### 3.1 Wireshark Settings

| Setting | Value |
|---------|-------|
| Interface | `en0` (Wi-Fi) |
| Capture filter (optional) | `host 10.7.17.151 or host 10.7.15.236` |
| **nginx HTTPS port** | **8443** (not 443 — brew nginx runs unprivileged) |
| Display filter (analysis) | see Section 4 |
| Output file | `evidence/script7/pcap/script7_[TIMESTAMP].pcapng` |

### 3.2 Pre-capture checklist

- [ ] DNS cache flushed (`sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder`)
- [ ] Wireshark started and capturing on `en0`
- [ ] nginx running (`brew services list | grep nginx`)
- [ ] Backend A reachable: `curl http://10.7.10.0:3001/api/status`
- [ ] Backend B reachable: `curl http://10.7.16.36:3002/api/status`

---

## 4. Packet Analysis

### 4.1 Display Filters Used

```
# DNS only
dns

# TCP handshake to nginx
tcp and ip.addr == 10.7.17.151 and (tcp.flags.syn == 1 or tcp.flags.ack == 1)

# TLS handshake
tls and ip.addr == 10.7.17.151

# All TLS application data
tls.record.content_type == 23

# Full conversation to nginx port 8443
tcp.port == 8443 and ip.addr == 10.7.17.151
```

---

### 4.2 DNS Query / Response

**Display filter:** `dns`

| Field | Value |
|-------|-------|
| Packet # (Query) | [FILL] |
| Packet # (Response) | [FILL] |
| Source IP (Query) | [FILL — client IP] |
| Destination IP (Query) | 10.7.15.236 (Mac 1 dnsmasq) |
| Protocol | DNS / UDP port 53 |
| Query name | `app.team1.test` |
| Response — Answer | `app.team1.test → 10.7.17.151` |
| Response TTL | [FILL] |

**Screenshot:** `evidence/script7/screenshots/dns_query_response.png`

**Explanation:**
The client had no cached record for `app.team1.test` after the cache flush. It sent a DNS A-record query (Type A, Class IN) to the dnsmasq server on Mac 1 (10.7.15.236:53). dnsmasq responded with a single A record mapping `app.team1.test` to `10.7.17.151` (Mac 2 / nginx). The client now knows which IP to connect to.

---

### 4.3 TCP Three-Way Handshake

**Display filter:** `tcp.port == 443 and ip.addr == 10.7.17.151`

| Step | Flag | Packet # | Source | Destination | Info |
|------|------|----------|--------|-------------|------|
| SYN | SYN | [FILL] | [client IP]:[ephemeral] | 10.7.17.151:443 | Seq=0 |
| SYN-ACK | SYN,ACK | [FILL] | 10.7.17.151:443 | [client IP]:[ephemeral] | Seq=0 Ack=1 |
| ACK | ACK | [FILL] | [client IP]:[ephemeral] | 10.7.17.151:443 | Ack=1 |

**Screenshot:** `evidence/script7/screenshots/tcp_handshake.png`

**Explanation:**
The client opens a TCP connection to nginx on 10.7.17.151:443. The SYN initiates the connection, nginx responds with SYN-ACK confirming it accepts, and the client sends ACK to complete the handshake. No application data is exchanged yet — this is pure transport-layer setup before TLS begins.

---

### 4.4 TLS Handshake

**Display filter:** `tls and ip.addr == 10.7.17.151`

| TLS Message | Packet # | Direction | Notes |
|-------------|----------|-----------|-------|
| Client Hello | [FILL] | Client → 10.7.17.151 | TLS 1.2/1.3, SNI=app.team1.test, cipher suites list |
| Server Hello | [FILL] | 10.7.17.151 → Client | Chosen cipher suite, session ID |
| Certificate | [FILL] | 10.7.17.151 → Client | nginx serves team1.test.crt (self-signed) |
| Server Hello Done | [FILL] | 10.7.17.151 → Client | (TLS 1.2) |
| Client Key Exchange | [FILL] | Client → 10.7.17.151 | Pre-master secret (TLS 1.2) |
| Change Cipher Spec | [FILL] | Client → 10.7.17.151 | Switching to encrypted |
| Change Cipher Spec | [FILL] | 10.7.17.151 → Client | nginx confirms encrypted |
| Finished | [FILL] | Both | Handshake complete |

> **Note on TLS 1.3:** If nginx negotiates TLS 1.3, the handshake is compressed — Certificate and Key Exchange are encrypted inside EncryptedExtensions. Wireshark will show fewer distinct messages but `tls` filter still reveals Client Hello / Server Hello with the SNI field.

**Screenshot:** `evidence/script7/screenshots/tls_handshake.png`

**Key detail to annotate:**
- In Client Hello: expand `Extension: server_name` → verify SNI = `app.team1.test`
- In Certificate: expand to show issuer = self-signed (CN=team1.test)

**Explanation:**
After the TCP handshake, TLS negotiation begins. The Client Hello advertises supported TLS versions and cipher suites, and includes the SNI (Server Name Indication) extension so nginx knows which certificate to serve. nginx returns its self-signed `team1.test.crt`. Once the key exchange completes, both sides switch to encrypted communication. All subsequent packets are opaque.

---

### 4.5 Encrypted Application Data

**Display filter:** `tls.record.content_type == 23 and ip.addr == 10.7.17.151`
*(Content type 23 = Application Data)*

| Direction | Packet # | Length | Notes |
|-----------|----------|--------|-------|
| Client → nginx | [FILL] | [FILL] bytes | Encrypted HTTP request (GET /api/status) |
| nginx → Client | [FILL] | [FILL] bytes | Encrypted HTTP response |

**Screenshot:** `evidence/script7/screenshots/tls_application_data.png`

**Explanation:**
These packets contain the actual HTTP/1.1 request and response, but they are fully encrypted by TLS. Wireshark shows them as `Application Data` with a length — the content is not readable from the capture alone. The HTTP headers (including `X-Backend`) are only visible through the `curl -v` output recorded separately (see Section 5).

> **Integrity note:** No HTTP payload contents are claimed from the Wireshark capture. All HTTP-level observations (headers, status codes, backend identity) come exclusively from the curl tool output in `evidence/script7/curl_output/`.

---

### 4.6 Source / Destination IP and Port Summary

| # | Layer | Src IP | Src Port | Dst IP | Dst Port | Protocol |
|---|-------|--------|----------|--------|----------|----------|
| 1 | DNS Query | [client] | ephemeral | 10.7.15.236 | 53 | UDP |
| 2 | DNS Response | 10.7.15.236 | 53 | [client] | ephemeral | UDP |
| 3 | TCP SYN | [client] | [ephemeral] | 10.7.17.151 | 8443 | TCP |
| 4 | TCP SYN-ACK | 10.7.17.151 | 8443 | [client] | [ephemeral] | TCP |
| 5 | TCP ACK | [client] | [ephemeral] | 10.7.17.151 | 8443 | TCP |
| 6 | TLS Client Hello | [client] | [ephemeral] | 10.7.17.151 | 8443 | TLSv1.x |
| 7 | TLS Server Hello + Cert | 10.7.17.151 | 8443 | [client] | [ephemeral] | TLSv1.x |
| 8 | TLS App Data (request) | [client] | [ephemeral] | 10.7.17.151 | 8443 | TLSv1.x |
| 9 | TLS App Data (response) | 10.7.17.151 | 8443 | [client] | [ephemeral] | TLSv1.x |

> Fill [client] and [ephemeral] with actual values from your capture.

---

## 5. curl Evidence — HTTP Headers

All curl output is saved in `evidence/script7/curl_output/`.

### 5.1 Verbose Single Request

```bash
curl -v \
  --cacert configs/tls/team1.test.crt \
  --resolve app.team1.test:8443:10.7.17.151 \
  https://app.team1.test:8443/api/status
```

Key fields to record from output:

| Field | Expected Value |
|-------|---------------|
| TLS version | TLSv1.2 or TLSv1.3 |
| Cipher suite | [FILL from output] |
| Certificate subject | CN=team1.test (or app.team1.test) |
| HTTP status | 200 OK |
| X-Backend header | A or B |
| Server header | nginx/[version] |

**Actual output file:** `evidence/script7/curl_output/verbose_single_[TIMESTAMP].txt`

---

### 5.2 Round-Robin Load Balancing (8 requests)

```bash
for i in {1..8}; do
  curl -sI \
    --cacert configs/tls/team1.test.crt \
    --resolve app.team1.test:8443:10.7.17.151 \
    https://app.team1.test:8443/api/status \
    | grep -i "x-backend:"
  sleep 0.3
done
```

**Expected pattern (round-robin):**

| Request | X-Backend |
|---------|-----------|
| 1 | A |
| 2 | B |
| 3 | A |
| 4 | B |
| 5 | A |
| 6 | B |
| 7 | A |
| 8 | B |

**Actual output file:** `evidence/script7/curl_output/roundrobin_[TIMESTAMP].txt`

**Actual observed pattern:** [FILL from output]

---

### 5.3 Direct Backend Checks (bypass nginx)

```bash
# Backend A
curl -sv http://10.7.10.0:3001/api/status

# Backend B
curl -sv http://10.7.16.36:3002/api/status
```

| Backend | IP:Port | HTTP Status | X-Backend Header |
|---------|---------|-------------|-----------------|
| A | 10.7.10.0:3001 | [FILL] | A |
| B | 10.7.16.36:3002 | [FILL] | B |

**Actual output file:** `evidence/script7/curl_output/direct_backends_[TIMESTAMP].txt`

---

## 6. Evidence Files Checklist

| File | Location | Status |
|------|----------|--------|
| Wireshark capture | `evidence/script7/pcap/*.pcapng` | [ ] |
| DNS screenshot | `evidence/script7/screenshots/dns_query_response.png` | [ ] |
| TCP handshake screenshot | `evidence/script7/screenshots/tcp_handshake.png` | [ ] |
| TLS handshake screenshot | `evidence/script7/screenshots/tls_handshake.png` | [ ] |
| TLS app data screenshot | `evidence/script7/screenshots/tls_application_data.png` | [ ] |
| curl verbose output | `evidence/script7/curl_output/verbose_single_*.txt` | [ ] |
| curl round-robin output | `evidence/script7/curl_output/roundrobin_*.txt` | [ ] |
| curl direct backends | `evidence/script7/curl_output/direct_backends_*.txt` | [ ] |

---

## 7. Script 7 Completion Conditions

- [ ] Wireshark .pcapng saved with a complete request visible
- [ ] DNS query and response packets identified and annotated
- [ ] TCP SYN → SYN-ACK → ACK identified with packet numbers
- [ ] TLS handshake packets identified (Client Hello with SNI visible)
- [ ] Encrypted application data packets present (content NOT claimed)
- [ ] Source/destination IPs and ports recorded for all 9 key packets
- [ ] curl verbose output shows TLS version, cipher, cert, status 200
- [ ] X-Backend: A observed in curl output
- [ ] X-Backend: B observed in curl output (round-robin confirmed)
- [ ] All files saved to evidence/script7/

---

## 8. Notes / Observations

[FILL during capture — anything unexpected, retry needed, filter adjustments, etc.]

---

## 9. Next Step

Script 8 — Phase 1 Failure Tests:
- Kill Backend A → verify nginx fails over to B only
- Kill Backend B → verify nginx fails over to A only
- Kill nginx → verify connection refused (no fallback at edge)
