# SCRIPT 8 — Phase 1 Failure Tests Completion Report

## TEST 1: Wrong DNS Server
* **Initial State**: DNS is working normally.
* **Fault Injected**: Queried Google's public DNS (`8.8.8.8`) instead of our private DNS (`10.7.15.236`).
* **Command**: `dig app.team1.test @8.8.8.8 +short`
* **Observation**: No IP address returned.
* **Layer Identified**: DNS Layer
* **Cause**: Public DNS servers do not have records for our private `.test` domain.
* **Restoration**: Reverted to querying `@10.7.15.236`.

## TEST 2: Wrong DNS Record
* **Initial State**: `app.team1.test` correctly resolves to `10.7.17.151`.
* **Fault Injected**: Temporarily changed `dnsmasq.conf` to point to a non-existent IP (`10.7.17.99`) and restarted `dnsmasq`.
* **Command**: `curl -s -v -k --resolve app.team1.test:8443:10.7.17.99 https://app.team1.test:8443/api/status`
* **Observation**: Connection timed out / Connection refused.
* **Layer Identified**: TCP Layer (TCP SYN sent, no SYN-ACK received).
* **Cause**: The DNS resolved to an IP where no server was listening, so the TCP handshake failed.
* **Restoration**: Restored `dnsmasq.conf` to point back to `10.7.17.151`.

## TEST 3: Stop Backend A
* **Initial State**: Both backends running.
* **Fault Injected**: Asked teammate on Mac 3 to stop Backend A.
* **Command**: `curl -s -v -k --resolve app.team1.test:8443:10.7.17.151 https://app.team1.test:8443/api/status`
* **Observation**: We still received responses from Backend A (`{"backend": "A", "status": "ok"}`) and Backend B.
* **Layer Identified**: Application / HTTP Layer.
* **Cause**: Because we implemented HTTP Caching in Script 6 (`Cache-Control: max-age=60`), the Nginx Edge Server (Mac 2) had the responses cached. Even though Backend A was stopped, Nginx served the cached response without actually forwarding the request to Mac 3.
* **Restoration**: Asked Mac 3 to start Backend A again.

## TEST 4: Stop Backend B
* **Initial State**: Both backends running.
* **Fault Injected**: Asked teammate on Mac 4 to stop Backend B.
* **Command**: `curl -s -v -k --resolve app.team1.test:8443:10.7.17.151 https://app.team1.test:8443/api/status`
* **Observation**: We continuously received responses from Backend A (`{"backend": "A", "status": "ok"}`).
* **Layer Identified**: Application / HTTP Layer.
* **Cause**: Nginx recognized that Backend B was down and automatically failed over to Backend A (or served from cache). Because Backend A was running (or cached), all requests were successfully fulfilled by Backend A.
* **Restoration**: Asked Mac 4 to start Backend B again.

## TEST 5: Stop Both Backends
* **Initial State**: Both backends running.
* **Fault Injected**: Asked both Mac 3 and Mac 4 to stop their backend servers.
* **Command**: `curl -s -v -k --resolve app.team1.test:8443:10.7.17.151 https://app.team1.test:8443/api/status`
* **Observation**: The request STILL succeeded! We received a `200 OK` with `X-Backend: A`.
* **Layer Identified**: Application / HTTP Layer.
* **Cause**: Nginx still had the response from Backend A in its HTTP Cache (`max-age=60`). When it realized both upstreams were down, it served the cached response. This demonstrates how caching adds resilience to the system!
* **Restoration**: Both backends restarted.

## TEST 6: Wrong Destination Port
* **Initial State**: Normal working state.
* **Fault Injected**: Attempted to connect to port `9999` instead of `8443`.
* **Command**: `curl -s -v -k --resolve app.team1.test:9999:10.7.17.151 https://app.team1.test:9999/api/status`
* **Observation**: Connection refused.
* **Layer Identified**: TCP Layer.
* **Cause**: Nginx is not listening on port 9999, so the OS immediately rejected the TCP connection with a RST packet.
* **Restoration**: Reverted to port 8443.
