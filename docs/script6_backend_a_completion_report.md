# Script 6 — Completion Report
> HTTP Caching & Conditional Revalidation | P3 (Mac 3 — Krishiv / Backend A)

---

## Status: ✅ COMPLETE

**Done condition met:** Caching behavior fully visible in headers, validated directly and via nginx HTTPS reverse proxy, and documented.
- `Cache-Control: max-age=60` on all successful responses (`/` and `/api/status`).
- `Cache-Control: no-store` on error responses (4xx/5xx) — errors must never be cached.
- `ETag` implemented as an MD5 hash of the response body — content-derived, self-updating.
- Conditional GET (`If-None-Match`) produces `304 Not Modified` with zero body transfer.
- Both `Cache-Control` and `ETag` survive the nginx TLS termination edge proxy over HTTPS.
- `do_HEAD` handler added for RFC 7231 compliance.

---

## What Was Done

| Step | Action | Result |
|------|--------|--------|
| 1 | `git pull origin` | Up to date |
| 2 | Started `backend_a/server.py` | Running on `0.0.0.0:3001` |
| 3 | Confirmed `Cache-Control: max-age=60` on `/` and `/api/status` | Present in all 2xx responses |
| 4 | Replaced static ETag `"backend-a-v1"` with MD5 hash of body | Auto-updates if body changes |
| 5 | Added `Cache-Control: no-store` on 4xx/5xx responses | Errors never cached |
| 6 | Added `do_HEAD` method | Fixed 501 on HEAD requests (RFC 7231) |
| 7 | Verified headers survive nginx HTTPS proxy | `Cache-Control` and `ETag` pass through intact |
| 8 | Demonstrated 304 conditional revalidation | `If-None-Match` match → 304, no body |

---

## Implementation Details

**File:** `backend_a/server.py`

### Cache-Control (success vs error)
```python
def _send_common_headers(self, status: int):
    self.send_response(status)
    self.send_header("X-Backend", "A")
    if status < 400:
        self.send_header("Cache-Control", "max-age=60")  # cache successful responses
    else:
        self.send_header("Cache-Control", "no-store")    # never cache errors
```

### ETag — content-derived via MD5
```python
import hashlib

STATUS_BODY = json.dumps({"backend": "A", "status": "ok"}).encode()
STATUS_ETAG = '"' + hashlib.md5(STATUS_BODY).hexdigest()[:16] + '"'
# → "72db076608216f33"
```
The ETag is derived from the actual body bytes. If the response body ever changes,
the ETag automatically changes too — no manual constant to forget to update.

### Conditional request handler (ETag / If-None-Match)
```python
def _handle_status(self, send_body: bool = True):
    if_none_match = self.headers.get("If-None-Match", "")
    if if_none_match and if_none_match == STATUS_ETAG:
        self._send_common_headers(304)       # cache hit — no body
        self.send_header("ETag", STATUS_ETAG)
        self.end_headers()
        return
    # ... 200 with full body + ETag
```

### HEAD support
```python
def do_HEAD(self):
    """HEAD — same headers as GET, no body (RFC 7231 §4.3.2)."""
    self._dispatch(send_body=False)
```

---

## Test Results

### Test 1 — Fresh request via nginx HTTPS (cache miss → 200)

```
curl -s --resolve app.team1.test:8443:10.7.17.151 \
     https://app.team1.test:8443/api/status -D - -o /dev/null

HTTP/1.1 200 OK
Server: nginx/1.31.6
X-Backend: A
Cache-Control: max-age=60
ETag: "72db076608216f33"
Content-Type: application/json
Content-Length: 32
```

✅ `Cache-Control: max-age=60` survives nginx HTTPS proxy
✅ `ETag: "72db076608216f33"` survives nginx HTTPS proxy
✅ Full 32-byte body returned

---

### Test 2 — Fresh request direct to Backend A (baseline → 200)

```
curl -sI http://localhost:3001/api/status

HTTP/1.0 200 OK
X-Backend: A
Cache-Control: max-age=60
ETag: "72db076608216f33"
Content-Type: application/json
Content-Length: 32
```

✅ All cache headers present at origin

---

### Test 3 — Conditional request, ETag match → 304 Not Modified

```
curl -sv http://localhost:3001/api/status \
     -H 'If-None-Match: "72db076608216f33"'

HTTP/1.0 304 Not Modified
X-Backend: A
Cache-Control: max-age=60
ETag: "72db076608216f33"
                              ← no body (0 bytes)
```

✅ 304 returned — server confirms cached copy is still fresh
✅ No response body — bandwidth saved
✅ ETag echoed back

---

### Test 4 — Conditional request, ETag mismatch → 200 with full body

```
curl -sv http://localhost:3001/api/status \
     -H 'If-None-Match: "stale-etag"'

HTTP/1.0 200 OK
X-Backend: A
Cache-Control: max-age=60
ETag: "72db076608216f33"
Content-Length: 32

{"backend": "A", "status": "ok"}
```

✅ Stale cache correctly invalidated — fresh body returned

---

### Test 5 — Error response gets no-store

```
curl -sI http://localhost:3001/doesnotexist

HTTP/1.0 404 Not Found
X-Backend: A
Cache-Control: no-store
Content-Type: text/plain
```

✅ 404 is never cached — `no-store` prevents stale "Not Found" being served

---

## Cache Scenario Summary

| Scenario | Client sends | Server responds | Body |
|---|---|---|---|
| **Fresh request** | No cache headers | `200` + `Cache-Control: max-age=60` + `ETag` | Full (32 bytes) |
| **Cache hit (within 60s)** | *(no request — served from local cache)* | — | None |
| **Conditional (fresh)** | `If-None-Match: "72db076608216f33"` | `304 Not Modified` | None (0 bytes) |
| **Conditional (stale)** | `If-None-Match: "stale-etag"` | `200` + new `ETag` | Full (32 bytes) |
| **Error** | Any | `404` + `Cache-Control: no-store` | Error text |

---

## ETag Design Note

The ETag is computed as the first 16 hex characters of the MD5 digest of the response body:

```
MD5({"backend": "A", "status": "ok"}) → 72db076608216f33...
ETag: "72db076608216f33"
```

Since Backend A and Backend B return different JSON (`"backend": "A"` vs `"backend": "B"`),
they correctly produce different ETags. This is per RFC 7232 — ETags represent the state of
the resource, and the resources have genuinely different content.

**Round-robin note:** With nginx load-balancing across both backends, a conditional request
from a client may land on a different backend than the one that issued the original ETag.
Since the ETags differ (different bodies), this returns 200 instead of 304. This is
correct HTTP behaviour — a shared proxy cache or sticky sessions would be needed for
consistent conditional caching across a load-balanced pool.

---

## Backend A Management

```bash
# Start
cd /Users/krishiv/Documents/GitHub/CN_Project
python3 backend_a/server.py

# Verify
curl -s http://localhost:3001/api/status
# → {"backend": "A", "status": "ok"}

# Check cache headers
curl -sI http://localhost:3001/api/status
# → Cache-Control: max-age=60 | ETag: "72db076608216f33"

# Test 304
curl -sv http://localhost:3001/api/status -H 'If-None-Match: "72db076608216f33"'
# → HTTP/1.0 304 Not Modified
```

---

## Assumptions

- Backend A is on Mac 3 (Krishiv) at `10.7.16.201:3001`
- ETag is MD5-derived — body is static so the ETag is effectively constant, but will auto-update if the body changes
- `max-age=60` means clients may serve cached responses for up to 60 seconds before revalidating
- DNS / nginx / TLS configuration not modified (P2 remains unchanged)
