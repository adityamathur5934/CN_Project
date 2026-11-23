# Extension C — Backend B Isolation: Verification Plan

## Prerequisite

Mac 2's current IP is recorded in `CN_PROJECT_LIVE_CONFIG.md` as `10.7.11.31`.
Confirm this with Aditya before running verification. The pf rules use `MAC2_IP=10.7.11.31`.
If the IP has changed, update `pf_setup.sh` and reload: `sudo pfctl -f /etc/pf.conf`.

---

## Proof Point A: Mac 2 → port 3002 succeeds

**Who runs this:** Aditya (Mac 2, IP 10.7.11.31)

```bash
# From Mac 2's terminal:
curl -v http://10.7.2.96:3002/
curl -v http://10.7.2.96:3002/api/status
```

Expected result:
- HTTP 200 response with `X-Backend: B` header
- Connection established without timeout or connection-refused

Alternative (run from Mac 4, simulating Mac 2's source IP — requires routing control):
```bash
# If Mac 2 is unavailable, test via nginx end-to-end:
curl --cacert /Users/vaidehisahu/CN/configs/tls/team.test.crt \
  https://app.team1.test:8443/api/status
# Should return X-Backend: B on some requests (round-robin)
```

---

## Proof Point B: Unauthorized host → port 3002 fails

**Important note:** Mac 4 is both the Backend B host AND the test client.
A connection from Mac 4's own `en0` interface (`10.7.2.96`) will appear as loopback/local
and may not be blocked by the inbound pf rule the same way as an external host.

**Preferred test method (use a third host):**
```bash
# From Mac 1 (Om, IP 10.7.10.8) or Mac 3 (Krishiv, IP 10.7.28.25):
curl -v --connect-timeout 5 http://10.7.2.96:3002/
```
Expected result: connection refused or timeout — NOT an HTTP 200.

**Alternative (from Mac 4 itself, using a different interface if available):**
```bash
# List available interfaces:
ifconfig -l
# If a second interface exists (e.g., en1, utun0), try:
curl -v --interface en1 --connect-timeout 5 http://10.7.2.96:3002/
```

**Fallback verification (pf rule inspection without live test):**
```bash
# Confirm the block rule is in the anchor:
sudo pfctl -a com.cn-project.backend-b-isolation -s rules
# Expected output includes:
#   block in quick on en0 proto tcp to any port = 3002
```

---

## Proof Point C: app.team1.test HTTPS still works

**Who runs this:** Any team member

```bash
# Using the team's CA certificate for proper validation (no -k flag):
curl -v --cacert /Users/vaidehisahu/CN/configs/tls/team.test.crt \
  https://app.team1.test:8443/

curl -v --cacert /Users/vaidehisahu/CN/configs/tls/team.test.crt \
  https://app.team1.test:8443/api/status
```

Expected result:
- HTTP 200 response
- TLS handshake succeeds (certificate validation passes)
- Requests round-robin between Backend A (`X-Backend: A`) and Backend B (`X-Backend: B`)

**If the cert path is different**, find it with:
```bash
find /Users/vaidehisahu/CN -name '*.crt' -o -name '*.pem' | head -20
```

---

## Summary Checklist

| Test | Command | Expected | Run From |
|------|---------|----------|----------|
| A: Mac 2 reaches port 3002 | `curl http://10.7.2.96:3002/` | HTTP 200 | Mac 2 (Aditya) |
| B: Unauthorized host blocked | `curl --connect-timeout 5 http://10.7.2.96:3002/` | Timeout / refused | Mac 1 or Mac 3 |
| C: HTTPS end-to-end works | `curl --cacert <cert> https://app.team1.test:8443/api/status` | HTTP 200, valid TLS | Any Mac |

---

## MAC2_IP Confirmation

Current value in `CN_PROJECT_LIVE_CONFIG.md`: `10.7.11.31`
`lan_inventory.md` records an older value: `10.7.17.151`

**Confirm with Aditya which IP is current before running pf_setup.sh.**
The variable `MAC2_IP` at the top of `pf_setup.sh` must match Mac 2's actual active IP.

To update if the IP has changed:
1. Edit `MAC2_IP` in `/Users/vaidehisahu/CN/evidence/phase2/pf_setup.sh`
2. Re-run: `sudo bash /Users/vaidehisahu/CN/evidence/phase2/pf_setup.sh`
