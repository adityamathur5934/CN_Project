# Evidence — Extension A: Backup DNS Failover

This directory holds evidence collected during the live backup DNS failover test.

## Files to capture during testing

| File | How to capture | What it proves |
|------|---------------|----------------|
| `primary_resolves.txt` | `dig app.team1.test @10.7.10.8 +noall +answer +stats > evidence/phase2/extension_a/primary_resolves.txt` | Primary DNS is answering before the test |
| `backup_resolves.txt` | `dig app.team1.test @10.7.2.96 +noall +answer +stats > evidence/phase2/extension_a/backup_resolves.txt` | Backup DNS is answering before the test |
| `primary_killed.txt` | `pgrep -fl dnsmasq > evidence/phase2/extension_a/primary_killed.txt` before and after kill | Shows primary process went away |
| `failover_proof.txt` | `dig app.team1.test @10.7.2.96 +noall +answer +comments > evidence/phase2/extension_a/failover_proof.txt` | Backup answered after primary was killed |
| `server_field.txt` | `dig app.team1.test @10.7.2.96 > evidence/phase2/extension_a/server_field.txt` | "SERVER: 10.7.2.96#53" appears in output |

## Failover procedure (run on Mac 1)

```zsh
# 1. Confirm primary is working
dig app.team1.test @10.7.10.8 +short

# 2. Confirm backup is working
dig app.team1.test @10.7.2.96 +short

# 3. Kill primary DNS on Mac 1
sudo killall dnsmasq

# 4. Query backup — must still resolve
dig app.team1.test @10.7.2.96

# 5. Restore primary DNS on Mac 1
sudo /opt/homebrew/sbin/dnsmasq -C /Users/tanish/Om_Kar_CN_Project/CN_Project/config/dnsmasq.conf

# 6. Confirm primary is restored
dig app.team1.test @10.7.10.8 +short
```
