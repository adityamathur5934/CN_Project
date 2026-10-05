# LAN Foundation — IP & Service Inventory
**CN Project — Stage 0 — COMPLETE**

---

## Domain

```
app.team3.test   →  Mac 2  (10.7.17.151)
api.team3.test   →  Mac 2  (10.7.17.151)
```

---

## IP & Role Summary

| Mac   | Role              | Private IPv4   | Port   | Subnet        | Gateway    |
|-------|-------------------|----------------|--------|---------------|------------|
| Mac 1 | DNS Server (P1)   | 10.7.15.236    | 53     | 10.7.0.0/19   | 10.7.0.1   |
| Mac 2 | Edge / nginx (P2) | 10.7.17.151    | 443    | 10.7.0.0/19   | 10.7.0.1   |
| Mac 3 | Backend A (P3)    | 10.7.16.201      | 3001   | 10.7.0.0/19   | 10.7.0.1   |
| Mac 4 | Backend B (P4)    | 10.7.16.36     | 3002   | 10.7.0.0/19   | 10.7.0.1   |

---

## Mac 3 — Backend A (THIS MACHINE)

| Field            | Value               |
|------------------|---------------------|
| Role             | Backend A           |
| Active Interface | en0 (Wi-Fi)         |
| Private IPv4     | **10.7.16.201**       |
| Subnet / Prefix  | 10.7.0.0/19         |
| Default Gateway  | 10.7.0.1            |
| MAC Address      | f2:9a:11:de:26:a2   |
| Service Port     | **3001**            |

---

## Service Port Summary

| Machine | Role       | Port(s)    |
|---------|------------|------------|
| Mac 1   | DNS        | 53 UDP/TCP |
| Mac 2   | nginx edge | 443 HTTPS  |
| Mac 3   | Backend A  | 3001 TCP   |
| Mac 4   | Backend B  | 3002 TCP   |

---

## Pairwise Ping Results (from Mac 3)

| Destination        | Role       | Result          | RTT avg   |
|--------------------|------------|-----------------|-----------|
| 10.7.15.236 (Mac1) | DNS        | ✅ 0% loss      | ~69 ms    |
| 10.7.17.151 (Mac2) | Edge/nginx | ✅ 25% loss*    | ~10 ms    |
| 10.7.16.36  (Mac4) | Backend B  | ✅ 0% loss      | ~22 ms    |

*25% loss to Mac 2 is likely host firewall dropping ICMP — TCP connectivity
(which nginx and curl use) will work fine.

---

## Topology Diagram

```
              Private Wi-Fi / LAN  (10.7.0.0/19)
              Gateway: 10.7.0.1
  ┌────────────────────────────────────────────────────┐
  │                                                    │
  │  Mac 1 (10.7.15.236)        Mac 2 (10.7.17.151)   │
  │  DNS Server                 Edge / nginx            │
  │  dnsmasq :53                HTTPS :443              │
  │                             Load Balancer           │
  │                                  │                 │
  │              ┌───────────────────┴──────────┐      │
  │              │                              │      │
  │  Mac 3 (10.7.16.201)            Mac 4 (10.7.16.36)  │
  │  Backend A :3001              Backend B :3002      │
  │                                                    │
  │  Clients: Mac 1, Mac 4                             │
  └────────────────────────────────────────────────────┘

Request flow:
  Client ──DNS query──► Mac 1 (10.7.15.236, dnsmasq)
         ◄── app.team3.test = 10.7.17.151 ──────────
  Client ──HTTPS :443──► Mac 2 (10.7.17.151, nginx)
                              │
              ┌───────────────┴───────────────┐
              ▼                               ▼
     Mac 3 :3001 (Backend A)        Mac 4 :3002 (Backend B)
     X-Backend: A                   X-Backend: B
```

---

## Handoff Values for P2 (nginx upstream config)

```
backend A:  10.7.16.201:3001
backend B:  10.7.16.36:3002
```

---

## Done Condition Checklist — Stage 0

- [x] All 4 Macs on same /19 LAN (10.7.0.0/19)
- [x] Mac 1 IP: 10.7.15.236
- [x] Mac 2 IP: 10.7.17.151
- [x] Mac 3 IP: 10.7.16.201 (confirmed via ifconfig)
- [x] Mac 4 IP: 10.7.16.36
- [x] Mac 3 → Mac 1 ping: 0% loss
- [x] Mac 3 → Mac 2 ping: reachable (minor ICMP drop, TCP fine)
- [x] Mac 3 → Mac 4 ping: 0% loss
- [x] Domain chosen: app.team3.test
- [x] Ports assigned: Mac2=443, Mac3=3001, Mac4=3002

## Stage 0: COMPLETE ✅
