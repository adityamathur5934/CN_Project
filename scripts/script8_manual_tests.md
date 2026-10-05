# Script 8 — Manual Failure Tests Guide
## Tests 1, 2, and 6 (DNS + Port failures)

These three tests require either a DNS change or a curl flag — no automation needed.
Run each one, record the output, then restore before moving to the next.

---

## TEST 1 — Wrong DNS Server

**Layer:** DNS (Layer 7 / Application — name resolution)
**Expected failure:** `curl: (6) Could not resolve host`

### Step 1 — Record initial state (Mac 2)
```zsh
scutil --dns | grep "nameserver\[0\]"
# Should show 10.7.15.236
```

### Step 2 — Inject fault (Mac 2 terminal)
Point DNS to a non-existent server:
```zsh
sudo networksetup -setdnsservers Wi-Fi 10.7.99.99
sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder
```

### Step 3 — Run test
```zsh
curl -v --cacert configs/tls/team1.test.crt https://app.team1.test:8443/api/status 2>&1 | tee evidence/script8/test1_wrong_dns/test1_output.txt
```

### Step 4 — Record observation
Expected output:
```
* Could not resolve host: app.team1.test
curl: (6) Could not resolve host: app.team1.test
```

### Step 5 — Restore (Mac 2)
```zsh
sudo networksetup -setdnsservers Wi-Fi 10.7.15.236
sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder
```

### Step 6 — Verify restore
```zsh
nslookup app.team1.test
# Must show: Address: 10.7.17.151
```

**Layer:** DNS
**Cause:** The resolver at 10.7.99.99 doesn't exist so the query times out. Without an IP address, no TCP connection can be attempted — the failure happens before any packet reaches nginx.

---

## TEST 2 — Wrong DNS Record

**Layer:** DNS → TCP (resolves but connects to wrong IP)
**Expected failure:** `Connection refused` or wrong server response

### Step 1 — Record initial state (Mac 1 — Om)
Ask Om to show current dnsmasq entry:
```zsh
cat /opt/homebrew/etc/dnsmasq.conf | grep team1
# Should show: address=/app.team1.test/10.7.17.151
```

### Step 2 — Inject fault (Mac 1 — Om does this)
Ask Om to temporarily change the A record to a wrong IP:
```zsh
# On Mac 1 — edit dnsmasq.conf
# Change: address=/app.team1.test/10.7.17.151
# To:     address=/app.team1.test/10.7.99.99
sudo brew services restart dnsmasq
```

### Step 3 — Run test (Mac 2)
Flush cache first, then test:
```zsh
sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder
curl -v --cacert configs/tls/team1.test.crt https://app.team1.test:8443/api/status 2>&1 | tee evidence/script8/test2_wrong_record/test2_output.txt
```

### Step 4 — Record observation
Expected output:
```
* Trying 10.7.99.99:8443...
* connect to 10.7.99.99 port 8443 failed: Operation timed out
curl: (28) Failed to connect to app.team1.test port 8443
```

### Step 5 — Restore (Mac 1 — Om)
```zsh
# On Mac 1 — revert dnsmasq.conf
# Change back: address=/app.team1.test/10.7.17.151
sudo brew services restart dnsmasq
```

Then on Mac 2:
```zsh
sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder
nslookup app.team1.test
# Must show: Address: 10.7.17.151
```

**Layer:** DNS resolved successfully but returned wrong IP. TCP SYN is sent to the wrong host — either refused (no service there) or times out (no host at that IP). The failure happens at TCP layer, caused by a DNS layer misconfiguration.

---

## TEST 6 — Wrong Destination Port

**Layer:** TCP
**Expected failure:** `Connection refused` immediately

### Step 1 — Record initial state
```zsh
# Confirm nginx is on 8443
sudo lsof -iTCP:8443 -sTCP:LISTEN
```

### Step 2 — Inject fault
No config change needed — just use the wrong port in curl:
```zsh
curl -v --cacert configs/tls/team1.test.crt \
  --resolve app.team1.test:9999:10.7.17.151 \
  https://app.team1.test:9999/api/status 2>&1 | tee evidence/script8/test6_wrong_port/test6_output.txt
```

### Step 3 — Record observation
Expected output:
```
* Trying 10.7.17.151:9999...
* connect to 10.7.17.151 port 9999 failed: Connection refused
curl: (7) Failed to connect to app.team1.test port 9999
```

### Step 4 — Restore
Nothing to restore — nginx config was never changed.
Confirm system is still healthy:
```zsh
curl -s --cacert configs/tls/team1.test.crt \
  --resolve app.team1.test:8443:10.7.17.151 \
  https://app.team1.test:8443/api/status
# Should return: {"backend": "A" or "B", "status": "ok"}
```

**Layer:** TCP
**Cause:** The IP is correct (DNS worked), but port 9999 has no listener. The OS on Mac 2 immediately sends a TCP RST (reset) back, resulting in instant `Connection refused`. No TLS handshake is ever attempted.

---

## Running all 3 tests — quick reference

| Test | Who acts | Command/action | Restore |
|------|----------|---------------|---------|
| 1 — Wrong DNS server | Mac 2 (you) | `networksetup -setdnsservers Wi-Fi 10.7.99.99` | `networksetup -setdnsservers Wi-Fi 10.7.15.236` |
| 2 — Wrong DNS record | Mac 1 (Om) | Edit dnsmasq.conf, restart dnsmasq | Revert dnsmasq.conf, restart dnsmasq |
| 6 — Wrong port | Mac 2 (you) | `curl ... :9999` | Nothing — no change made |
