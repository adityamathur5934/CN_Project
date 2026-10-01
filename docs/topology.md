# Network Topology — CN Project
> Private Network Service Platform | Team LAN on 10.7.0.0/19

---

## Architecture Diagram

```
                        ┌─────────────────────────────────────┐
                        │         PRIVATE LAN: 10.7.0.0/19    │
                        │         Gateway: 10.7.0.1            │
                        └──────────────┬──────────────────────┘
                                       │
              ┌────────────────────────┼────────────────────────┐
              │                        │                        │
              ▼                        ▼                        ▼
   ┌─────────────────┐      ┌──────────────────┐    ┌─────────────────┐
   │     MAC 1       │      │      MAC 2 ★     │    │     MAC 4       │
   │  Private DNS    │      │  Edge / nginx    │    │  Backend B      │
   │  P1             │      │  P2 (YOU)        │    │  + Test Client  │
   │                 │      │                  │    │  P4             │
   │  IP: [P1_IP]   │      │  IP: 10.7.17.151 │    │  IP: [P4_IP]   │
   │  Port: 53      │      │  Port: 443(HTTPS) │    │  Port: 3002    │
   │  dnsmasq       │◄─────│  Port: 80(HTTP)  │    │  GET /api/status│
   │                 │      │                  │    │  X-Backend: B  │
   │  app.team.test  │      │  TLS termination │    └────────┬────────┘
   │  → 10.7.17.151  │      │  Reverse proxy   │             │
   └────────┬────────┘      │  Load balancer   │    ┌────────▼────────┐
            │               └────────┬─────────┘    │     MAC 3       │
            │  DNS queries            │              │  Backend A      │
            │  resolved here          │              │  P3             │
            ▼                        │              │                 │
   ┌─────────────────┐               │              │  IP: [P3_IP]   │
   │  Client Macs    │               │              │  Port: 3001    │
   │  (Mac 1, Mac 4) │               │              │  GET /api/status│
   │                 │               │              │  X-Backend: A  │
   │  DNS: [P1_IP]  │               └──────────────►└─────────────────┘
   │                 │                    nginx upstream:
   └─────────────────┘                    [P3_IP]:3001 (Backend A)
                                          [P4_IP]:3002 (Backend B)
```

---

## Request Flow (Full Stack)

```
Browser / curl on Client Mac
        │
        │  1. DNS QUERY
        │     "app.team.test → ?"
        ▼
   Mac 1 (dnsmasq)
        │  DNS Response: 10.7.17.151
        │
        ▼
   Mac 2 — nginx (10.7.17.151:443)
        │
        │  2. TCP SYN → SYN-ACK → ACK  (three-way handshake)
        │  3. TLS ClientHello → ServerHello → Certificate
        │     → Key Exchange → Finished  (TLS handshake)
        │  4. Encrypted HTTP/1.1 GET /api/status
        │
        │  nginx reverse proxies to upstream (round-robin)
        │
        ├──────────────────────────────────────►  Mac 3:3001 (Backend A)
        │  round 1: X-Backend: A                  HTTP (plain, internal)
        │
        └──────────────────────────────────────►  Mac 4:3002 (Backend B)
           round 2: X-Backend: B                  HTTP (plain, internal)
```

---

## Layer Mapping (OSI / TCP-IP)

| Layer | Protocol | Component |
|-------|----------|-----------|
| 7 — Application | HTTP/1.1, REST, JSON | nginx, Backend A/B |
| 6 — Presentation | TLS 1.2/1.3 | nginx (TLS termination) |
| 5 — Session | TLS session | nginx ↔ client |
| 4 — Transport | TCP | All connections; ports 443, 3001, 3002 |
| 3 — Network | IPv4 | 10.7.0.0/19 addressing |
| 2 — Data Link | Ethernet / 802.11 Wi-Fi | en0 on each Mac |
| 1 — Physical | Wi-Fi radio / cable | LAN hardware |

DNS uses **UDP port 53** (Layer 4 Transport / Layer 3 Network) — it runs *before* TCP connections are made.

---

## Phase 2 Additional Components

```
                        ┌─────────────────────────────────────┐
                        │      PHASE 2 ADDITIONS               │
                        └──────────────────────────────────────┘

  Backup DNS (Extension A):
  ┌──────────────┐     ┌──────────────┐
  │  Mac 1       │     │  Standby DNS │
  │  Primary DNS │     │  (another Mac│
  │  [P1_IP]:53  │     │  same records│
  └──────────────┘     └──────────────┘
    Clients list both — if primary stops, backup resolves

  Backend Firewall Isolation (Extension C):
  ┌──────────────┐         ┌──────────────┐
  │  Mac 2 only  │ ──OK──► │ Mac 3 :3001  │
  │  (nginx)     │         │ Mac 4 :3002  │
  └──────────────┘         └──────────────┘
    ┌──────────────┐         ┌──────────────┐
    │ Other clients│ ─BLOCK─►│ Mac 3 :3001  │
    │              │         │ Mac 4 :3002  │
    └──────────────┘         └──────────────┘

  Standby Edge / DNS Migration (Extension E):
  ┌──────────────┐           ┌───────────────┐
  │  Mac 2       │ ──DNS──►  │  Standby Mac  │
  │  Primary edge│  migration│  nginx copy   │
  │  10.7.17.151 │           │  [STANDBY_IP] │
  └──────────────┘           └───────────────┘
    app.team.test DNS record updated from 10.7.17.151 → [STANDBY_IP]
    Old cached clients temporarily reach old edge (TTL demonstration)
```

---

## Key IP / Port Quick Reference

| Hostname           | IP            | Port(s)   | Owner |
|--------------------|---------------|-----------|-------|
| Mac 1 (DNS)        | [P1_IP]       | 53        | P1    |
| Mac 2 (Edge/nginx) | **10.7.17.151** | **443**, 80 | **P2 (YOU)** |
| Mac 3 (Backend A)  | [P3_IP]       | 3001      | P3    |
| Mac 4 (Backend B)  | [P4_IP]       | 3002      | P4    |

> Replace `[P1_IP]`, `[P3_IP]`, `[P4_IP]` with actual IPs from teammates.
> Replace `team` in `team.test` with your actual team name/number.

---

## Cloud Equivalents (for Viva)

| Local Component        | Cloud Equivalent                     |
|------------------------|--------------------------------------|
| Mac 1 — dnsmasq        | AWS Route 53 / Azure DNS             |
| Mac 2 — nginx + TLS    | AWS ALB / CloudFront / GCP LB        |
| Mac 3 — Backend A:3001 | AWS EC2 / App Server instance A      |
| Mac 4 — Backend B:3002 | AWS EC2 / App Server instance B      |
| pf firewall rules      | AWS Security Groups / NACLs          |
| Backup DNS             | Route 53 health-check failover       |
| Standby nginx          | Blue/green deployment                |
