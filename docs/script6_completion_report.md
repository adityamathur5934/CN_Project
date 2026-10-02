# Script 6 — Completion Report
> HTTP Caching & Conditional Revalidation | P4 (Mac 4 — Vaidehi) & P3 (Mac 3 — Krishiv)

---

## Status: ✅ COMPLETE

**Done condition met:** Caching behavior is fully visible in headers, validated directly and via reverse proxy, and thoroughly documented.
- `Cache-Control: max-age=60` active on all endpoints.
- `ETag` implemented (`"backend-b-v1"`).
- Conditional GET (`If-None-Match`) produces `304 Not Modified` with zero redundant payload transfer.
- Both `Cache-Control` and `ETag` survive the nginx TLS termination edge proxy over HTTPS.

---

## What Was Done

| Step | Action | Result |
|------|--------|--------|
| 1 | Configured `Cache-Control: max-age=60` on Backend B endpoints (`/` and `/api/status`) | Present in all HTTP responses |
| 2 | Added constant `ETag` (`"backend-b-v1"`) to `/api/status` | ETag header returned on 200 responses |
| 3 | Added conditional request evaluation in `server.py` (`If-None-Match`) | Returns HTTP `304 Not Modified` without response body |
| 4 | Trusted team TLS certificate (`configs/tls/team1.test.crt`) in macOS Keychain | HTTPS requests succeed without `-k` |
| 5 | Verified end-to-end caching headers through Mac 2 nginx edge (`https://app.team1.test:8443`) | `Cache-Control` and `ETag` pass through intact |
| 6 | Verified end-to-end conditional 304 revalidation through nginx edge | 304 Not Modified returned cleanly through reverse proxy |
| 7 | Created automated test script `scripts/test_caching.sh` | All 4 validation checks pass ✅ |

---

## Caching Concepts Explained

### 1. Fresh Request (Cache Miss / First Fetch)
When a client requests a resource for the first time (or after the cache entry has expired):
- **Request**: Client sends a standard `GET /api/status`.
- **Response**: Server returns `HTTP/1.0 200 OK` along with full JSON payload, `Cache-Control: max-age=60`, and `ETag: "backend-b-v1"`.
- **Client Action**: Client caches the response body and associates it with `max-age=60` and the given ETag.

### 2. Cache Hit (Local Cache Freshness)
- While the response age is within the `max-age=60` window:
- The client (browser, HTTP proxy, or client-side caching library) serves the response directly from its local cache without making any network call.
- Network latency: **0 ms**. Bandwidth used: **0 bytes**.

### 3. Conditional Request / Cache Revalidation (304 Not Modified)
- Once the `max-age=60` expires, the cached data is considered "stale".
- Rather than refetching the entire payload, the client asks the server if the resource has actually changed:
  ```http
  GET /api/status HTTP/1.1
  Host: app.team1.test:8443
  If-None-Match: "backend-b-v1"
  ```
- **If resource has not changed**: Server replies with `HTTP/1.1 304 Not Modified`, updating the cache freshness with zero payload body transfer.
- **If resource changed**: Server sends `HTTP 200 OK` with the new body and a new ETag.

---

## Test Evidence

### Test 1: Direct Backend B — Fresh Request (HTTP 200)
**Command:**
```bash
curl -s -D - "http://10.7.16.36:3002/api/status"
```
**Output:**
```http
HTTP/1.0 200 OK
Server: BackendB/1.0 Python/3.9.6
Date: Fri, 02 Oct 2026 15:36:28 GMT
X-Backend: B
Cache-Control: max-age=60
Content-Type: application/json; charset=utf-8
Content-Length: 32
ETag: "backend-b-v1"

{"backend": "B", "status": "ok"}
```

---

### Test 2: Direct Backend B — Conditional Request (HTTP 304)
**Command:**
```bash
curl -s -D - -H 'If-None-Match: "backend-b-v1"' "http://10.7.16.36:3002/api/status"
```
**Output:**
```http
HTTP/1.0 304 Not Modified
Server: BackendB/1.0 Python/3.9.6
Date: Fri, 02 Oct 2026 15:36:28 GMT
X-Backend: B
Cache-Control: max-age=60
ETag: "backend-b-v1"
```

---

### Test 3: Nginx Edge — Header Survival over HTTPS (HTTP 200, no `-k`)
**Command:**
```bash
curl -s -D - --resolve app.team1.test:8443:10.7.17.151 "https://app.team1.test:8443/api/status"
```
**Output:**
```http
HTTP/1.1 200 OK
Server: nginx/1.31.6
Date: Fri, 02 Oct 2026 15:36:29 GMT
Content-Type: application/json; charset=utf-8
Content-Length: 32
Connection: keep-alive
X-Backend: B
Cache-Control: max-age=60
ETag: "backend-b-v1"

{"backend": "B", "status": "ok"}
```

---

### Test 4: Nginx Edge — Conditional Revalidation over HTTPS (HTTP 304, no `-k`)
**Command:**
```bash
curl -s -D - -H 'If-None-Match: "backend-b-v1"' --resolve app.team1.test:8443:10.7.17.151 "https://app.team1.test:8443/api/status"
```
**Output:**
```http
HTTP/1.1 304 Not Modified
Server: nginx/1.31.6
Date: Fri, 02 Oct 2026 15:36:29 GMT
Connection: keep-alive
X-Backend: B
Cache-Control: max-age=60
ETag: "backend-b-v1"
```

---

## Verification Suite Run
Command: `./scripts/test_caching.sh`
```
═══════════════════════════════════════════════════════════
  Script 6 — HTTP Caching & Revalidation Verification     
  Backend B: 10.7.16.36:3002  |  Edge: https://app.team1.test:8443 
═══════════════════════════════════════════════════════════

[1/4] Direct Backend B — Fresh Request (HTTP 200)
  ✅ PASS — Status code: HTTP 200 OK
  ✅ PASS — Cache-Control: max-age=60
  ✅ PASS — ETag: "backend-b-v1"
  ✅ PASS — X-Backend: B

[2/4] Direct Backend B — Conditional Request (If-None-Match → 304)
  ✅ PASS — Status code: HTTP 304 Not Modified
  ✅ PASS — Conditional request validated: client cache is fresh, body transfer omitted

[3/4] Nginx Edge — Header Survival over HTTPS
  ✅ PASS — Status code: HTTP 200 OK through reverse proxy
  ✅ PASS — Cache-Control survived nginx: max-age=60
  ✅ PASS — ETag survived nginx: "backend-b-v1"

[4/4] Nginx Edge — Conditional Request Revalidation (HTTP 304)
  ✅ PASS — Status code: HTTP 304 Not Modified through nginx edge
  ✅ PASS — End-to-end conditional GET succeeded: Client ➔ Nginx ➔ Backend B ➔ 304

═══════════════════════════════════════════════════════════
  Script 6 DONE CONDITION:
  ✅ Cache-Control: max-age=60 present on / and /api/status
  ✅ ETag header present and consistent
  ✅ Conditional GET (If-None-Match) returns 304 Not Modified
  ✅ All caching headers survive nginx edge reverse proxy
  ✅ Certificate trusted without -k
═══════════════════════════════════════════════════════════
```
