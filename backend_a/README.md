# Backend A — Mac 3 (P3)

HTTP REST backend for the CN Project. Listens on `0.0.0.0:3001`.

## Start

```bash
python3 server.py
```

Expected startup output:
```
[Backend A] Listening on 0.0.0.0:3001  (LAN IP: 10.7.10.0:3001)
[Backend A] Endpoints:  GET /   GET /api/status
[Backend A] Press Ctrl-C to stop.
```

## Stop

Press `Ctrl-C`, or from another terminal:
```bash
kill $(lsof -ti:3001)
```

## Endpoints

### GET /
```
HTTP/1.0 200 OK
X-Backend: A
Cache-Control: max-age=60
Content-Type: text/plain

Backend A is running
```

### GET /api/status
```
HTTP/1.0 200 OK
X-Backend: A
Cache-Control: max-age=60
Content-Type: application/json
ETag: "backend-a-v1"

{"backend": "A", "status": "ok"}
```

### Conditional GET /api/status (304)
```bash
curl -si -H 'If-None-Match: "backend-a-v1"' http://10.7.10.0:3001/api/status
# → 304 Not Modified (empty body)
```

## Local Verification (run on Mac 3)

```bash
curl -si http://127.0.0.1:3001/
curl -si http://127.0.0.1:3001/api/status
curl -si http://10.7.10.0:3001/api/status
```

## Remote Verification (run from Mac 2 / P2)

```bash
curl -si http://10.7.10.0:3001/api/status
```
Expected: HTTP 200, `X-Backend: A`, `{"backend": "A", "status": "ok"}`

## Handoff to P2 (nginx upstream)

```
upstream backend_a:  10.7.10.0:3001
```

## Implementation Notes

- Pure Python 3 stdlib (`http.server`) — no pip installs needed
- Binds to `0.0.0.0` so Mac 2 can reach it over the LAN
- `X-Backend: A` present on every response (200, 304, 404)
- `Cache-Control: max-age=60` on all responses (Phase 2 caching)
- ETag + `If-None-Match` → 304 for conditional requests (Phase 2)
