# Evidence — Extension B: DNS TTL Demonstration

This directory holds evidence collected during the TTL / cache cutover demonstration.

## Files to capture during testing

| File | How to capture | What it proves |
|------|---------------|----------------|
| `ttl_query.txt` | `dig app.team1.test @10.7.10.8 +noall +answer > evidence/phase2/extension_b/ttl_query.txt` | Answer section shows TTL = 30 |
| `old_answer_cached.txt` | Query immediately after changing DNS record | Client still sees old IP (cached) |
| `new_answer_after_expiry.txt` | Query 30+ seconds after changing DNS record (or after flush) | Client sees new IP |
| `cache_flush.txt` | `sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder` | Shows explicit flush step |

## TTL demonstration procedure (run on Mac 1)

```zsh
# 1. Confirm TTL is 30 seconds
dig app.team1.test @10.7.10.8

# Expected answer section:
# app.team1.test.  30  IN  A  10.7.11.31

# 2. Change the record to a test IP to simulate migration
# Edit config/dnsmasq.conf: change address=/app.team1.test/10.7.11.31 to address=/app.team1.test/10.7.11.99
sudo sed -i '' 's|address=/app.team1.test/10.7.11.31|address=/app.team1.test/10.7.11.99|' \
    /Users/tanish/Om_Kar_CN_Project/CN_Project/config/dnsmasq.conf

# 3. Restart dnsmasq to apply the change
sudo killall dnsmasq
sudo /opt/homebrew/sbin/dnsmasq -C /Users/tanish/Om_Kar_CN_Project/CN_Project/config/dnsmasq.conf

# 4. Query immediately — a caching client may still return the old answer
dig app.team1.test @10.7.10.8
# If dnsmasq's own cache is cold this will show 10.7.11.99 immediately.
# To show a client-side cached old answer, query the client OS resolver:
# dig app.team1.test  (no @server — uses system resolver which may have cached the old answer)

# 5. Wait 30 seconds (or flush the client OS cache)
sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder

# 6. Query again — must now show the new IP
dig app.team1.test @10.7.10.8

# 7. Rollback to production IP
sudo sed -i '' 's|address=/app.team1.test/10.7.11.99|address=/app.team1.test/10.7.11.31|' \
    /Users/tanish/Om_Kar_CN_Project/CN_Project/config/dnsmasq.conf
sudo killall dnsmasq
sudo /opt/homebrew/sbin/dnsmasq -C /Users/tanish/Om_Kar_CN_Project/CN_Project/config/dnsmasq.conf
dig app.team1.test @10.7.10.8
```
