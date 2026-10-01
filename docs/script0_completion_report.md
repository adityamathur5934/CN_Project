# Script 0 — Completion Report
> Team LAN Setup | P2 (Mac 2) | CN Project

---

## Status: ✅ MAC 2 COMPLETE — ⏳ Waiting for teammates

---

## What Script 0 Required

> Per the project AI agent prompt:
> "Connect all team Macs to the same private Wi-Fi/LAN. Record for each Mac: private IPv4 address,
> subnet/prefix, default gateway, active interface, MAC address. Verify pairwise reachability with ping.
> Assign roles. Choose a .test domain. Record service ports. Create a topology diagram."

---

## P2 (Mac 2) — Verified Network State

**Inspection run on Mac 2:**

```
$ ifconfig en0 | grep inet
inet 10.7.17.151 netmask 0xffffe000 broadcast 10.7.31.255

$ ifconfig en0 | grep ether
ether a2:24:e2:34:6f:4d

$ netstat -rn | grep "^default"
default  10.7.0.1  UGScg  en0
```

| Field            | Value               |
|------------------|---------------------|
| Private IPv4     | **10.7.17.151**     |
| Subnet / Prefix  | 255.255.224.0 / /19 |
| Network          | 10.7.0.0/19         |
| Broadcast        | 10.7.31.255         |
| Default Gateway  | 10.7.0.1            |
| Active Interface | en0 (Wi-Fi / LAN)   |
| MAC Address      | a2:24:e2:34:6f:4d   |
| Hostname         | Adityas-MacBook-Pro-2.local |

**Gateway ARP entry confirmed (gateway reachable at Layer 2):**
```
$ arp -n 10.7.0.1
10.7.0.1  c0:c5:20:6f:38:ee  en0
```

---

## Team IP / Service Inventory

| Role        | Machine | Person | IPv4            | Service Port | Status          |
|-------------|---------|--------|-----------------|--------------|-----------------|
| DNS Server  | Mac 1   | P1     | [FILL IN — P1]  | 53 (UDP/TCP) | ⏳ Need from P1 |
| Edge/nginx  | Mac 2   | P2     | **10.7.17.151** | 443 / 80     | ✅ Confirmed    |
| Backend A   | Mac 3   | P3     | [FILL IN — P3]  | 3001 (TCP)   | ⏳ Need from P3 |
| Backend B   | Mac 4   | P4     | [FILL IN — P4]  | 3002 (TCP)   | ⏳ Need from P4 |

---

## Role Assignments

| Person | Machine | Primary Role                              |
|--------|---------|-------------------------------------------|
| P1     | Mac 1   | Private DNS Server (dnsmasq) + Test Client |
| **P2** | **Mac 2** | **Edge / Reverse Proxy / Load Balancer / TLS (nginx)** |
| P3     | Mac 3   | Backend Server A — HTTP REST :3001        |
| P4     | Mac 4   | Backend Server B + Test Client — HTTP REST :3002 |

---

## Domain Name

| Domain          | Resolves To     | Set By |
|-----------------|-----------------|--------|
| app.team.test   | 10.7.17.151     | P1 (dnsmasq) |
| api.team.test   | 10.7.17.151     | P1 (dnsmasq) |

> **Action required:** Agree with the team on the actual team identifier.
> Replace `team` with your team name/number (e.g., `team4.test`, `teamA.test`).
> Do NOT use `.local` — conflicts with macOS Bonjour/mDNS.

---

## Pairwise Ping Verification

> Run once all IPs are collected. Command: `ping -c 3 <TARGET_IP>`

### From Mac 2 (P2 runs these):

```bash
# Ping Mac 1 (DNS)
ping -c 3 <P1_IP>

# Ping Mac 3 (Backend A)
ping -c 3 <P3_IP>

# Ping Mac 4 (Backend B)
ping -c 3 <P4_IP>
```

| Pair             | Command                   | Result     |
|------------------|---------------------------|------------|
| Mac 2 → Mac 1    | ping -c 3 [P1_IP]         | ⏳ Pending |
| Mac 2 → Mac 3    | ping -c 3 [P3_IP]         | ⏳ Pending |
| Mac 2 → Mac 4    | ping -c 3 [P4_IP]         | ⏳ Pending |

### Expected output (success):
```
PING 10.7.x.x: 56 data bytes
64 bytes from 10.7.x.x: icmp_seq=0 ttl=64 time=X.X ms
64 bytes from 10.7.x.x: icmp_seq=1 ttl=64 time=X.X ms
64 bytes from 10.7.x.x: icmp_seq=2 ttl=64 time=X.X ms
--- 10.7.x.x ping statistics ---
3 packets transmitted, 3 packets received, 0.0% packet loss
```

### If ping fails (troubleshooting):
1. Confirm both Macs are on the same LAN — check IPs are both in 10.7.0.0/19
2. Check target Mac's firewall: `sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getblockall`
3. Try `arp -n <TARGET_IP>` — if no ARP entry, the machines may be on different subnets
4. Confirm active interface with `ifconfig | grep inet`

---

## Script 0 Done Conditions Checklist

| Condition                                           | Status          |
|-----------------------------------------------------|-----------------|
| All 4 Macs connected to same LAN (10.7.0.0/19)     | ⏳ Verify with team |
| All 4 private IPv4 addresses recorded               | ⏳ Need P1/P3/P4 IPs |
| Mac 2 IP confirmed: 10.7.17.151                     | ✅ Done         |
| All pairwise pings attempted (Mac2↔Mac1/3/4)        | ⏳ Pending IPs  |
| Domain name agreed (.test namespace)                | ⏳ Confirm with team |
| Service ports confirmed (53 / 443 / 3001 / 3002)   | ✅ Plan confirmed |
| Topology diagram created                            | ✅ docs/topology.md |
| LAN inventory created                               | ✅ docs/lan_inventory.md |
| Inventory shared with all teammates                 | ⏳ Share this file |

---

## What P2 Has NOT Done (Script 0 Rule)

Per the Shared Agent Rules:
> "DO NOT configure application services yet."

The following are explicitly **not started** at this stage:
- nginx is NOT installed or configured
- TLS certificates are NOT created
- No ports are opened or bound
- No backend connections are made

All of the above begin at **Script 4** once P1/P3/P4 complete their components.

---

## Values P2 Needs from Teammates Before Script 4

| Value           | Needed From | Used For                        |
|-----------------|-------------|----------------------------------|
| P1's IP address | P1          | Knowing DNS server is up         |
| P3's IP address | P3          | nginx upstream: [P3_IP]:3001     |
| P4's IP address | P4          | nginx upstream: [P4_IP]:3002     |
| Agreed domain   | Team        | nginx server_name app.team.test  |
| P3 backend test | P3          | curl http://[P3_IP]:3001/api/status |
| P4 backend test | P4          | curl http://[P4_IP]:3002/api/status |

---

## Build Dependency Reminder

```
Script 0 (Everyone: LAN)         ← YOU ARE HERE ✅
    │
    ▼
Script 1 (P1: DNS)               ← Wait for P1
    │
    ├──► Script 2 (P3: Backend A)  ← Parallel with Script 3
    └──► Script 3 (P4: Backend B)  ← Parallel with Script 2
              │
              ▼
         Script 4 (P2: nginx)    ← P2's next action
              │
              ▼
         Script 5 (P2: HTTPS/TLS)
```

**P2's immediate next step:** Wait for P1 DNS checkpoint + P3/P4 backend IPs, then proceed to Script 4.
