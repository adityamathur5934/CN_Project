# CN Project — Live Configuration

## 1. Team

| Machine | Member | Role |
|---|---|---|
| Mac 1 | Om | Private DNS + Client |
| Mac 2 | Aditya | Edge / Reverse Proxy / Load Balancer |
| Mac 3 | Krishiv | Backend A |
| Mac 4 | Vaidehi | Backend B + Client |

---

## 2. Network

- Network: `10.7.0.0/19`
- Subnet mask: `255.255.224.0`
- Broadcast: `10.7.31.255`
- Gateway: `10.7.0.1`
- Active interface: `en0`

---

## 3. Machine Configuration

### Mac 1 — Om

- Role: DNS + Client
- IPv4: `10.7.15.236`
- Interface: `en0`
- Gateway: `10.7.0.1`
- DNS service: `dnsmasq`
- DNS port: `53/UDP`

### Mac 2 — Aditya

- Role: Edge / Reverse Proxy / Load Balancer
- IPv4: `10.7.17.151`
- Interface: `en0`
- Gateway: `10.7.0.1`
- Reverse proxy: `nginx`
- HTTP port: `8080/TCP` (redirects to HTTPS)
- HTTPS port: `8443/TCP` (TLS termination — brew nginx runs unprivileged)

### Mac 3 — Krishiv

- Role: Backend A
- IPv4: `10.7.16.201`
- Interface: `en0`
- Gateway: `10.7.0.1`
- HTTP port: `3001`

### Mac 4 — Vaidehi

- Role: Backend B + Client
- IPv4: `10.7.2.96`
- Interface: `en0`
- Gateway: `10.7.0.1`
- HTTP port: `3002`

---

## 4. DNS

Domain: `team1.test`

Records:

app.team1.test → `10.7.17.151`
api.team1.test → `10.7.17.151`

Expected:

app.team1.test → `10.7.17.151`
api.team1.test → `10.7.17.151`

---

## 5. nginx

Public entry point:

`https://app.team1.test:8443`

Listen:

`8080` (HTTP → redirect to HTTPS)
`8443` (HTTPS/TLS)

Backend A:

`10.7.16.201:3001`

Backend B:

`10.7.2.96:3002`

Load balancing:

Round-robin

---

## 6. Backend A

Host:

`10.7.16.201`

Port:

`3001`

Endpoints:

GET /
GET /api/status

Header:

X-Backend: A

---

## 7. Backend B

Host:

`10.7.2.96`

Port:

`3002`

Endpoints:

GET /
GET /api/status

Header:

X-Backend: B