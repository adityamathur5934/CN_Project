# Extension C — Live Test Results

---

## POST-ACTIVATION PROOF TESTS — 24 Nov 2026

### Proof Point A — Mac 2 (Aditya) → port 3002: PASS ✅

Aditya ran from Mac 2 (`10.7.11.31`):
```
curl http://10.7.2.96:3002/api/status
```
**Result:** `{"backend": "B", "status": "ok"}` — HTTP 200. Mac 2 (nginx proxy) can reach Backend B directly. ✅

---

### Proof Point B — Unauthorized host (Krishiv, Mac 3) → port 3002: PASS ✅

Krishiv ran from Mac 3 (`10.7.28.25`):
```
krishiv@krishivs-MacBook-Pro CN_Project % curl --connect-timeout 5 http://10.7.2.96:3002/
curl: (28) Failed to connect to 10.7.2.96 port 3002 after 5006 ms: Timeout was reached
```
**Result:** Timeout — connection blocked by pf. Unauthorized direct access denied. ✅

---

### Proof Point C — HTTPS end-to-end: PASS ✅

Already verified before activation (see below). nginx → Backend B path works through Mac 2.

---

## Summary: All Three Proof Points PASSED

| Test | Host | Result |
|------|------|--------|
| A: Allowed host (Mac 2) → port 3002 | Aditya, `10.7.11.31` | ✅ HTTP 200, `{"backend":"B","status":"ok"}` |
| B: Blocked host (Mac 3) → port 3002 | Krishiv, `10.7.28.25` | ✅ Timeout after 5006 ms |
| C: HTTPS app.team1.test:8443 | Mac 4 | ✅ TLSv1.3, cert validated, HTTP 200 |

---

## PRE-ACTIVATION BASELINE — 23 Nov 2026

Tested from Mac 4 (`10.7.2.96`) before pf rules were activated.
These confirm the baseline worked before isolation was applied.

---

## Backend B — Direct Loopback Test

```
curl -v http://127.0.0.1:3002/api/status
```

**Result: PASS**
```
HTTP/1.0 200 OK
Server: BackendB/1.0 Python/3.9.6
X-Backend: B
Cache-Control: max-age=60
ETag: "backend-b-v1"
Content-Type: application/json; charset=utf-8

{"backend": "B", "status": "ok"}
```

---

## ETag / 304 Not Modified — Backend B

```
curl -H 'If-None-Match: "backend-b-v1"' http://127.0.0.1:3002/api/status
```

**Result: PASS — 304 returned**
```
HTTP/1.0 304 Not Modified
Cache-Control: max-age=60
ETag: "backend-b-v1"
```

ETag/304 is confirmed and can be claimed in the viva.

---

## Proof Point C — HTTPS End-to-End via nginx (Mac 2)

Command (uses `--resolve` because Mac 1 DNS was offline at time of test):
```bash
curl -v --cacert /Users/vaidehisahu/CN/configs/tls/team1.test.crt \
  --resolve app.team1.test:8443:10.7.11.31 \
  https://app.team1.test:8443/
```

**Result: PASS**
```
SSL certificate verify ok.
  subject: CN=app.team1.test
  subjectAltName: host "app.team1.test" matched cert's "app.team1.test"
HTTP/1.1 200 OK
X-Backend: B
Cache-Control: max-age=60
Server: nginx/1.31.6

Backend B is running
```

TLS handshake: TLSv1.3 / AEAD-AES256-GCM-SHA384. Certificate validation passed without `-k`.

---

## Round-Robin Load Balancing — 6 Requests

```bash
for i in {1..6}; do
  curl -s --cacert .../team1.test.crt --resolve app.team1.test:8443:10.7.11.31 \
    https://app.team1.test:8443/api/status \
    -w "HTTP %{http_code} | X-Backend: %header{x-backend} | Cache-Control: %header{cache-control}\n" \
    -o /dev/null
done
```

**Result: PASS — strict round-robin between A and B**
```
Request 1 — HTTP 200 | X-Backend: B | Cache-Control: max-age=60
Request 2 — HTTP 200 | X-Backend: A | Cache-Control: max-age=60
Request 3 — HTTP 200 | X-Backend: B | Cache-Control: max-age=60
Request 4 — HTTP 200 | X-Backend: A | Cache-Control: max-age=60
Request 5 — HTTP 200 | X-Backend: B | Cache-Control: max-age=60
Request 6 — HTTP 200 | X-Backend: A | Cache-Control: max-age=60
```

Both `X-Backend: A` and `X-Backend: B` confirmed. `Cache-Control: max-age=60` confirmed on all.

---

## pf State (Pre-Activation)

```
Status: Disabled
Filter rules: Apple system anchors only (com.apple/*)
No application-level rules; port 3002 unrestricted.
```

This is the before-state. After `pf_setup.sh` runs, the isolation anchor will appear here.

---

## Mac 2 Reachability (ping from Mac 4)

```
ping -c 3 10.7.11.31
64 bytes from 10.7.11.31: icmp_seq=0 ttl=64 time=52.983 ms
64 bytes from 10.7.11.31: icmp_seq=1 ttl=64 time=8.916 ms
64 bytes from 10.7.11.31: icmp_seq=2 ttl=64 time=83.883 ms
0% packet loss
```

Mac 2 is on the LAN and reachable. `MAC2_IP=10.7.11.31` confirmed from `CN_PROJECT_LIVE_CONFIG.md`.

---

## Pending Tests (require activation + team coordination)

All three proof points are now complete. See post-activation results at the top of this file.
