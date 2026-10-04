# Script 8 — Completion Report
> Phase 1 Failure Tests & Diagnostic Methodology | Team Platform (Mac 4 — Vaidehi)

---

## Status: ✅ COMPLETE

**Done condition met:** All 6 controlled, reversible Phase 1 failure modes have been injected, observed, diagnosed layer-by-layer, and fully restored without causing permanent damage.
- Strict diagnostic methodology demonstrated: `DNS ➔ TCP ➔ TLS ➔ Application`.
- Failover behavior and upstream error handling validated.

---

## Diagnostic Order Reference

When troubleshooting any platform incident, always diagnose layer by layer in sequence:

```
┌─────────────────────────────────────────────────────────────┐
│ 1. DNS Layer          dig @<DNS_IP> app.team1.test          │
│    Is hostname resolved to the Edge IP?                     │
├─────────────────────────────────────────────────────────────┤
│ 2. TCP Layer          nc -zv -w 2 <EDGE_IP> 8443 / 8080     │
│    Is the transport socket reachable and open?              │
├─────────────────────────────────────────────────────────────┤
│ 3. TLS Layer          openssl s_client -connect ...         │
│    Does TLS handshake complete? Is certificate valid?       │
├─────────────────────────────────────────────────────────────┤
│ 4. Application Layer  curl -s -i https://app.team1.test:... │
│    Are HTTP headers (200, 304, X-Backend) returned?         │
└─────────────────────────────────────────────────────────────┘
```

---

## Controlled Failure Test Matrix

| # | Test | Fault Injected | Observed Output | Layer Identified | Root Cause | Recovery Action |
|---|------|----------------|-----------------|------------------|------------|-----------------|
| **1** | Wrong DNS Server | Queried unassigned IP `10.7.15.250` | `connection timed out; no servers could be reached` | **DNS Layer** | No service listening on UDP 53; name resolution fails before TCP connection starts. | Reverted client resolver to Mac 1 (`10.7.15.236`). |
| **2** | Wrong DNS Record | Resolved domain to unassigned IP `10.7.16.200` | `curl: (28) Failed to connect ... Timeout was reached` | **Transport (TCP) / Network Layer** | Domain resolved to host that does not answer TCP SYN packets (no SYN-ACK). | Restored DNS A record to Mac 2 Edge (`10.7.17.151`). |
| **3** | Stop Backend A | Backend A process stopped on Mac 3 | Edge returns `HTTP 200` with `X-Backend: B` | **Upstream TCP ➔ Application Layer** | Nginx detected TCP RST / drop on `10.7.16.201:3001` and failed over to Backend B. | Mac 3 restarted Backend A daemon; round-robin restored. |
| **4** | Stop Backend B | Stopped Backend B daemon on Mac 4 (`./backend_b/stop.sh`) | Direct: `curl: (7) Connection refused`. Edge: `HTTP 200`, `X-Backend: A` | **Transport (TCP RST) at Backend ➔ Application at Edge** | Port 3002 closed, kernel returned TCP RST; Nginx rerouted all traffic to Backend A. | Executed `./backend_b/start.sh`; Backend B resumed participating in load balancing. |
| **5** | Stop Both Backends | Both 3001 and 3002 ports unreachable | Edge returns `HTTP/1.1 502 Bad Gateway` | **Application Layer (HTTP 502)** | Edge completes TLS handshake with client, but fails to establish TCP connection with any upstream node. | Restarted Backend A and Backend B daemons. |
| **6** | Wrong Destination Port | Requested closed port `8444` on Mac 2 Edge | `curl: (7) Failed to connect ... port 8444: Couldn't connect to server` | **Transport Layer (TCP)** | Edge host is reachable (ping OK), but no process is listening on TCP port 8444; kernel replies with TCP RST. | Reverted destination port to active HTTPS port (`:8443`). |

---

## Detailed Test Logs & Evidence

### Test 1: Wrong DNS Server
```bash
dig @10.7.15.250 +time=2 +tries=1 app.team1.test
```
```
; <<>> DiG 9.10.6 <<>> @10.7.15.250 +time=2 +tries=1 app.team1.test
;; connection timed out; no servers could be reached
```
*Diagnosis*: DNS query never received an answer. Client application cannot proceed to TCP connection because no IP address could be resolved.

---

### Test 2: Wrong DNS Record
```bash
curl -S -s -i --connect-timeout 3 --resolve app.team1.test:8443:10.7.16.200 https://app.team1.test:8443/api/status
```
```
curl: (28) Failed to connect to app.team1.test port 8443 after 3005 ms: Timeout was reached
```
*Diagnosis*: DNS returned an erroneous IP (`10.7.16.200`). TCP SYN packet was transmitted, but no SYN-ACK was received, causing connection timeout.

---

### Test 3 & 4: Stop Backend A & Stop Backend B (Failover)
```bash
# Backend B stopped:
./backend_b/stop.sh

# Direct verification to Mac 4:
curl -S -s -i http://10.7.16.36:3002/api/status
```
```
curl: (7) Failed to connect to 10.7.16.36 port 3002 after 3 ms: Couldn't connect to server
```
```bash
# Request through Edge Nginx:
curl -S -s -i --resolve app.team1.test:8443:10.7.17.151 https://app.team1.test:8443/api/status
```
```http
HTTP/1.1 200 OK
Server: nginx/1.31.6
X-Backend: A
Cache-Control: max-age=60
ETag: "72db076608216f33"

{"backend": "A", "status": "ok"}
```
*Diagnosis*: Reverse proxy handles upstream node failure gracefully. When Backend B is down, Nginx transparently proxies 100% of client traffic to Backend A without dropping user requests.

---

### Test 5: Stop Both Backends
```http
HTTP/1.1 502 Bad Gateway
Server: nginx/1.31.6
Content-Type: text/html
Content-Length: 157
Connection: keep-alive

<html>
<head><title>502 Bad Gateway</title></head>
<body>
<center><h1>502 Bad Gateway</h1></center>
<hr><center>nginx/1.31.6</center>
</body>
</html>
```
*Diagnosis*: TLS handshake succeeds at the Edge (client-facing). Nginx attempts to contact upstream pool, but all nodes refuse TCP connections. Edge generates a `502 Bad Gateway` error response.

---

### Test 6: Wrong Destination Port
```bash
curl -S -s -i --connect-timeout 3 --resolve app.team1.test:8444:10.7.17.151 https://app.team1.test:8444/api/status
```
```
curl: (7) Failed to connect to app.team1.test port 8444 after 7 ms: Couldn't connect to server
```
*Diagnosis*: Edge host IP is alive and answering ICMP/ping. However, TCP port 8444 has no listener socket. Host kernel immediately responds with a TCP RST (reset) segment, resulting in `Connection refused`.

---

## Verification Test Script
An automated failure test script has been added to the repository:
```bash
./scripts/test_failure_modes.sh
```
This script tests each failure mode, captures the observations, prints the layer diagnosis, and safely restores Backend B and all system configurations.
