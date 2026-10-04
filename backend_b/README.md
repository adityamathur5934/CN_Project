# Backend B — Mac 4 (P4)

HTTP REST backend for the Computer Networks Project. Listens on `0.0.0.0:3002`.

---

## Machine Details

| Field            | Value                         |
|------------------|-------------------------------|
| Machine          | Mac 4                         |
| Primary Role     | Backend Server B + Test Client|
| LAN IP           | `10.7.16.36`                  |
| Port             | `3002` (TCP)                  |
| Header           | `X-Backend: B`                |

---

## Start Commands

### Foreground (interactive)
```bash
cd backend_b
python3 server.py
```

Expected startup output:
```
=================================================
[Backend B] Listening on 0.0.0.0:3002 (LAN IP: 10.7.16.36:3002)
[Backend B] Endpoints:  GET /   GET /api/status
[Backend B] Headers:    X-Backend: B, Cache-Control: max-age=60, ETag: "backend-b-v1"
[Backend B] Press Ctrl-C to stop.
=================================================
```

### Background
```bash
cd backend_b
./start.sh
```

---

## Stop Commands

Press `Ctrl-C` if running in foreground, or:
```bash
kill $(lsof -ti:3002)
```
Or via script:
```bash
./stop.sh
```

---

## Endpoints

### 1. `GET /`
```http
HTTP/1.0 200 OK
X-Backend: B
Cache-Control: max-age=60
Content-Type: text/plain; charset=utf-8

Backend B is running
```

### 2. `GET /api/status`
```http
HTTP/1.0 200 OK
X-Backend: B
Cache-Control: max-age=60
ETag: "backend-b-v1"
Content-Type: application/json; charset=utf-8

{"backend": "B", "status": "ok"}
```

### 3. Conditional Request (`If-None-Match` → 304 Not Modified)
```bash
curl -si -H 'If-None-Match: "backend-b-v1"' http://10.7.16.36:3002/api/status
```
Expected output:
```http
HTTP/1.0 304 Not Modified
X-Backend: B
Cache-Control: max-age=60
ETag: "backend-b-v1"
```

---

## Local Verification (run on Mac 4)

```bash
# Test root
curl -si http://127.0.0.1:3002/

# Test API status
curl -si http://127.0.0.1:3002/api/status

# Test LAN IP binding
curl -si http://10.7.16.36:3002/api/status
```

---

## Remote Verification (run from Mac 2 / P2 or Mac 1 / Mac 3)

```bash
curl -si http://10.7.16.36:3002/api/status
```

---

## Handoff Values for P2 (nginx upstream config)

```nginx
upstream backend_nodes {
    server 10.7.16.201:3001;   # Backend A (Mac 3)
    server 10.7.16.36:3002;  # Backend B (Mac 4)
}
```

---

## Implementation Notes

- Pure Python 3 stdlib (`http.server`, `socketserver`) — zero external dependencies
- Binds to `0.0.0.0:3002` so Mac 2 reverse proxy and other LAN hosts can reach it
- Multi-threaded (`ThreadingMixIn`) to handle concurrent requests
- `X-Backend: B` returned on every response
- `Cache-Control: max-age=60` and `ETag` implemented for Phase 2 caching requirements
- Conditional `304 Not Modified` on cache revalidation
