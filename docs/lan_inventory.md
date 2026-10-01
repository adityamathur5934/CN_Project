# Team LAN Inventory — CN Project
> Script 0 Output | Last Updated: [Fill in date when team meets]

---

## Network Foundation

| Parameter        | Value              |
|------------------|--------------------|
| LAN Subnet       | 10.7.0.0/19        |
| Subnet Mask      | 255.255.224.0      |
| Broadcast        | 10.7.31.255        |
| Default Gateway  | 10.7.0.1           |
| DNS (current)    | 8.8.8.8, 8.8.4.4  |
| Private Domain   | app.team.test      |

> **Note:** DNS will change to Mac 1's IP once P1 configures dnsmasq (Script 1).

---

## Machine Inventory

### Mac 2 — P2 (YOU — Edge / nginx) ✅ CONFIRMED

| Parameter       | Value              |
|-----------------|--------------------|
| Role            | Edge / Reverse Proxy / Load Balancer / TLS |
| Person          | P2 (Aditya)        |
| Interface       | en0 (Wi-Fi / LAN)  |
| Private IPv4    | 10.7.17.151        |
| Netmask         | 255.255.224.0 (/19)|
| Gateway         | 10.7.0.1           |
| MAC Address     | a2:24:e2:34:6f:4d  |
| Hostname        | Adityas-MacBook-Pro-2.local |
| Service Port    | 443 (HTTPS) / 8443 if 443 unavailable |
| DNS to serve    | app.team.test → 10.7.17.151 |

---

### Mac 1 — P1 (DNS Server) ⏳ FILL IN

| Parameter       | Value              |
|-----------------|--------------------|
| Role            | Private DNS Server + Test Client |
| Person          | P1                 |
| Interface       | [ASK P1]           |
| Private IPv4    | [ASK P1]           |
| Netmask         | [ASK P1]           |
| Gateway         | [ASK P1]           |
| MAC Address     | [ASK P1]           |
| Service         | dnsmasq port 53    |

---

### Mac 3 — P3 (Backend A) ⏳ FILL IN

| Parameter       | Value              |
|-----------------|--------------------|
| Role            | Backend Server A   |
| Person          | P3                 |
| Interface       | [ASK P3]           |
| Private IPv4    | [ASK P3]           |
| Netmask         | [ASK P3]           |
| Gateway         | [ASK P3]           |
| MAC Address     | [ASK P3]           |
| Service Port    | 3001               |
| Endpoint        | GET /api/status → { "backend": "A", "status": "ok" } |

---

### Mac 4 — P4 (Backend B + Client) ⏳ FILL IN

| Parameter       | Value              |
|-----------------|--------------------|
| Role            | Backend Server B + Test Client |
| Person          | P4                 |
| Interface       | [ASK P4]           |
| Private IPv4    | [ASK P4]           |
| Netmask         | [ASK P4]           |
| Gateway         | [ASK P4]           |
| MAC Address     | [ASK P4]           |
| Service Port    | 3002               |
| Endpoint        | GET /api/status → { "backend": "B", "status": "ok" } |

---

## Service Port Summary

| Machine | IP            | Port | Protocol | Service         |
|---------|---------------|------|----------|-----------------|
| Mac 1   | [P1_IP]       | 53   | UDP/TCP  | DNS (dnsmasq)   |
| Mac 2   | 10.7.17.151   | 443  | TCP      | HTTPS (nginx)   |
| Mac 2   | 10.7.17.151   | 80   | TCP      | HTTP → redirect |
| Mac 3   | [P3_IP]       | 3001 | TCP      | Backend A (HTTP)|
| Mac 4   | [P4_IP]       | 3002 | TCP      | Backend B (HTTP)|

---

## Domain Name Plan

| DNS Record             | Resolves To    | Purpose                  |
|------------------------|----------------|--------------------------|
| app.team.test          | 10.7.17.151    | Main HTTPS entry point   |
| api.team.test          | 10.7.17.151    | API entry point (alias)  |

> **Domain:** `team.test` — change `team` to your actual team identifier (e.g., `team4.test`, `teamX.test`)
> Do NOT use `.local` — conflicts with macOS mDNS/Bonjour.

---

## Pairwise Reachability Checklist

> Run `ping -c 3 <TARGET_IP>` from each machine. Fill in results.

| From → To         | IP Target     | Result   | Tested By |
|-------------------|---------------|----------|-----------|
| Mac2 → Mac1       | [P1_IP]       | ⏳ TODO  | P2        |
| Mac2 → Mac3       | [P3_IP]       | ⏳ TODO  | P2        |
| Mac2 → Mac4       | [P4_IP]       | ⏳ TODO  | P2        |
| Mac1 → Mac2       | 10.7.17.151   | ⏳ TODO  | P1        |
| Mac3 → Mac2       | 10.7.17.151   | ⏳ TODO  | P3        |
| Mac4 → Mac2       | 10.7.17.151   | ⏳ TODO  | P4        |
| Mac3 → Mac4       | [P4_IP]       | ⏳ TODO  | P3        |

---

## Script 0 Done Condition

- [ ] All 4 Macs confirmed on same LAN (10.7.0.0/19)
- [ ] All 4 IP addresses recorded above
- [ ] All pairwise pings pass (6 pairs minimum)
- [ ] Domain name agreed: `________.test`
- [ ] Service ports confirmed: Mac2=443, Mac3=3001, Mac4=3002, Mac1=53
- [ ] This inventory shared with all teammates

**Mac 2 (P2) is DONE with Script 0 — IP confirmed: 10.7.17.151**
