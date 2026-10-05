# CN PROJECT — FINAL DEMONSTRATION + VIVA SCRIPT
### Private Network Service Platform | Team 1 | Phase 1 Complete
> This document is an operational script. Follow it line by line during the live evaluation.
> Every command, every spoken line, every handoff, and every viva answer is written out in full.

---

# SECTION 1 — HOW OUR PROJECT WORKS (COMPLETE EXPLANATION)

## The Story of One Request

Imagine a user types `https://app.team1.test:8443` into a browser or curl on Mac 4.
Here is exactly what happens, step by step.

**Step 1 — The client needs an IP address.**
The browser knows the domain name `app.team1.test` but has no idea which machine to talk to.
It must ask a DNS server first.

**Step 2 — DNS query goes to Mac 1.**
Mac 4 is configured to use `10.7.15.236` as its DNS server. That is Om's Mac 1.
Mac 4 sends a DNS query over UDP to port 53: "What is the IP address of app.team1.test?"

**Step 3 — Mac 1 / dnsmasq answers.**
Om's dnsmasq has a record: `app.team1.test → 10.7.17.151`.
It sends back a DNS response: "The IP is 10.7.17.151."
DNS is now done. It played no further role in this connection.

**Step 4 — Mac 4 opens a TCP connection to Mac 2.**
Now that Mac 4 knows the IP, it initiates a TCP connection to `10.7.17.151` on port `8443`.
This is the three-way handshake:
- Mac 4 sends SYN ("I want to connect")
- Mac 2 / nginx replies SYN-ACK ("I accept")
- Mac 4 sends ACK ("connection confirmed")
The TCP channel is now open. No application data yet.

**Step 5 — TLS handshake establishes a secure channel.**
Before any HTTP data is sent, TLS negotiation happens:
- Mac 4 sends ClientHello: "I support TLS 1.3, here are my cipher suites"
- Mac 2 / nginx replies ServerHello: "Let's use TLS 1.3 with this cipher"
- nginx sends its certificate for `app.team1.test`
- Mac 4 verifies the certificate against its trusted store (the cert is installed on Mac 4)
- Both sides perform key exchange and derive a shared session key
- Both send Finished — the encrypted channel is now open

**Step 6 — The HTTPS request travels encrypted to nginx.**
Mac 4 sends the HTTP request (GET /api/status) inside the encrypted TLS tunnel.
No one watching the network can read it. Wireshark shows it only as "Application Data."

**Step 7 — nginx decrypts and reverse-proxies the request.**
nginx on Mac 2 terminates TLS — it decrypts the request.
nginx acts as a reverse proxy: it picks a backend from its upstream pool using round-robin.
Round 1: it sends the request (as plain HTTP) to Mac 3 at `10.7.16.201:3001` (Backend A).
Round 2: it sends the next request to Mac 4 at `10.7.2.96:3002` (Backend B).

**Step 8 — The backend generates and returns the response.**
Backend A or B receives a plain HTTP GET request from nginx.
It returns: `{"backend": "A", "status": "ok"}` with headers including `X-Backend: A` and `Cache-Control: max-age=60`.

**Step 9 — nginx forwards the response back to the client.**
nginx receives the backend response, adds its own headers, and sends it back to Mac 4 inside the TLS tunnel.

**Step 10 — Mac 4 receives the final HTTPS response.**
The client sees `200 OK` with the JSON body and all headers. The entire journey is complete.

**Step 11 — Wireshark lets us observe every layer.**
On the network capture, we can see: DNS on UDP/53, TCP handshake on TCP/8443, TLS handshake, and encrypted application data blobs. We cannot see the HTTP payload — proving HTTPS encryption works.

---

## Where Each Course Concept Appears

| Concept | Where It Appears in Our Project |
|---|---|
| DNS | Mac 1 dnsmasq resolves `app.team1.test` to `10.7.17.151` |
| IP Addressing | Every machine has a private IPv4 on 10.7.0.0/19 |
| Subnet | All four Macs are on 10.7.0.0/19 — same broadcast domain |
| Gateway | 10.7.0.1 — used when traffic needs to leave the LAN |
| TCP | Three-way handshake before every HTTP connection |
| Ports | DNS=53/UDP, HTTPS=8443/TCP, Backend A=3001/TCP, Backend B=3002/TCP |
| TLS | Terminates at nginx on Mac 2; backends receive plain HTTP |
| HTTPS | HTTP inside TLS — all application data is encrypted |
| nginx | Reverse proxy and load balancer on Mac 2 |
| Load Balancing | Round-robin across Backend A and Backend B |
| HTTP Headers | X-Backend identifies which backend served; Cache-Control controls caching |
| HTTP Caching | Cache-Control: max-age=60 + ETag + 304 Not Modified |
| Wireshark | Packet-level evidence of DNS, TCP, TLS, encrypted data |
| Failure Testing | Layer-by-layer diagnosis: DNS → TCP → TLS → Application |

---

# SECTION 2 — TEAM AND MACHINE CONFIGURATION

| Machine | Person | Role | IP | Port | Service |
|---|---|---|---|---|---|
| Mac 1 | Om | Private DNS Server + Test Client | 10.7.15.236 | 53/UDP | dnsmasq |
| Mac 2 | Aditya | Edge / Reverse Proxy / Load Balancer | 10.7.17.151 | 8443/TCP (HTTPS), 8080/TCP (HTTP→redirect) | nginx |
| Mac 3 | Krishiv | Backend Server A | 10.7.16.201 | 3001/TCP | Python HTTP server |
| Mac 4 | Vaidehi | Backend Server B + Test Client | 10.7.2.96 | 3002/TCP | Python HTTP server |

**Network:** 10.7.0.0/19 | **Subnet mask:** 255.255.224.0 | **Gateway:** 10.7.0.1 | **Domain:** `app.team1.test`

**Note on port 8443:** Homebrew nginx runs without root. Port 443 requires root. Port 8443 is the configured HTTPS port. The project spec explicitly states no marks are deducted for this substitution.

---

# SECTION 3 — COMPLETE NETWORK / PROTOCOL FLOW

| Stage | Protocol | Source | Destination | Port | What Happens |
|---|---|---|---|---|---|
| 1. DNS Query | DNS / UDP | Mac 4 (10.7.2.96) | Mac 1 (10.7.15.236) | 53/UDP | Client asks: "What is app.team1.test?" |
| 2. DNS Response | DNS / UDP | Mac 1 (10.7.15.236) | Mac 4 (10.7.2.96) | 53/UDP | dnsmasq answers: "10.7.17.151" |
| 3. TCP SYN | TCP | Mac 4 (ephemeral port) | Mac 2 (10.7.17.151) | 8443/TCP | Client initiates connection |
| 4. TCP SYN-ACK | TCP | Mac 2 (10.7.17.151) | Mac 4 (ephemeral port) | 8443/TCP | nginx accepts connection |
| 5. TCP ACK | TCP | Mac 4 (ephemeral port) | Mac 2 (10.7.17.151) | 8443/TCP | Handshake complete |
| 6. TLS ClientHello | TLS | Mac 4 | Mac 2 | 8443/TCP | Client advertises TLS versions, ciphers, SNI=app.team1.test |
| 7. TLS ServerHello + Cert | TLS | Mac 2 | Mac 4 | 8443/TCP | nginx selects TLS 1.3, sends team1.test.crt |
| 8. TLS Key Exchange + Finished | TLS | Both | Both | 8443/TCP | Shared key derived; encrypted channel open |
| 9. HTTPS Request | TLS App Data | Mac 4 | Mac 2 | 8443/TCP | Encrypted GET /api/status (invisible to Wireshark) |
| 10. nginx → Backend A | HTTP | Mac 2 (10.7.17.151) | Mac 3 (10.7.16.201) | 3001/TCP | Plain HTTP proxy request (internal) |
| 11. Backend A → nginx | HTTP | Mac 3 (10.7.16.201) | Mac 2 (10.7.17.151) | 3001/TCP | {"backend":"A","status":"ok"} + headers |
| 12. HTTPS Response | TLS App Data | Mac 2 | Mac 4 | 8443/TCP | Encrypted response returned to client |

---

# SECTION 4 — ROLES OF ALL FOUR TEAM MEMBERS

## During Normal Demo

| Demo Step | Om (Mac 1) | Aditya (Mac 2) | Krishiv (Mac 3) | Vaidehi (Mac 4) |
|---|---|---|---|---|
| Step 1 — Topology | Silent. dnsmasq running. | Silent. nginx running. | Silent. Backend A running. | **SPEAKS. Shows topology.** |
| Step 2 — LAN | Runs ping commands on cue. | Runs ping commands on cue. | Runs ping commands on cue. | **SPEAKS. Runs ping from Mac 4.** |
| Step 3 — DNS | Silent. dnsmasq running. | Silent. | Silent. | **SPEAKS. Runs dig from Mac 4.** |
| Step 4 — HTTPS | Silent. | Silent. nginx serving. | Silent. Backend A running. | **SPEAKS. Runs curl from Mac 4.** |
| Step 5 — Load Balancing | Silent. | Silent. | Silent. Backend A running. | **SPEAKS. Runs loop curl from Mac 4.** |
| Step 6 — Wireshark | Silent. | **Navigates Wireshark on Mac 2 on Vaidehi's cues.** | Silent. | **SPEAKS. Narrates Wireshark.** |
| Step 7 — Caching | Silent. | Silent. | Silent. | **SPEAKS. Runs curl from Mac 4.** |
| Step 8 — Failure | Silent. | Silent. | **Stops Backend A on cue. Restarts on cue.** | **SPEAKS. Runs curl from Mac 4.** |
| Step 9 — Phase 2 | **Demonstrates backup DNS on Mac 1 on cue.** | Silent. | Silent. | **SPEAKS. Narrates.** |
| Step 10 — Fault | All observe. | Fixes nginx if fault is there. | Fixes backend if fault is there. | **SPEAKS. Runs diagnostics.** |
| Step 11 — Viva | **Answers own questions.** | **Answers own questions.** | **Answers own questions.** | **Answers own questions.** |


---

# SECTION 5 — SCREEN MANAGEMENT PLAN

The faculty sees ONE projected screen at a time. Switching laptops mid-demo is chaotic. Follow this plan exactly.

| Demo Step | Primary Screen (Projected) | Handoff Trigger |
|---|---|---|
| Step 1 — Topology | **Mac 4 / Vaidehi** — CN_PROJECT_LIVE_CONFIG.md open in editor | Vaidehi says "Let's start the live demo" |
| Step 2 — LAN | **Mac 4 / Vaidehi** — Terminal | Vaidehi runs ping; teammates run pings on their own screens (not projected) |
| Step 3 — DNS | **Mac 4 / Vaidehi** — Terminal | No switch needed |
| Step 4 — HTTPS | **Mac 4 / Vaidehi** — Terminal | No switch needed |
| Step 5 — Load Balancing | **Mac 4 / Vaidehi** — Terminal | No switch needed |
| Step 6 — Wireshark | **Mac 2 / Aditya** — Wireshark + pcap open | Vaidehi says: *"Aditya, please take the screen."* |
| Step 7 — Caching | **Mac 4 / Vaidehi** — Terminal | Vaidehi says: *"I'll take the screen back."* |
| Step 8 — Failure | **Mac 4 / Vaidehi** — Terminal | No switch needed; Krishiv acts on his own Mac |
| Step 9 — Phase 2 | **Mac 1 / Om** — Terminal | Vaidehi says: *"Om, please take the screen."* |
| Step 10 — Fault | **Mac 4 / Vaidehi** — Terminal (diagnosis) | Whoever has the faulty component takes screen if needed |
| Step 11 — Viva | Each person takes their own Mac when addressed | Faculty calls each person by name |

**Rule:** Mac 4 (Vaidehi) is the default projected screen. Switch only when explicitly noted above.
**Before the demo:** All four Macs should have their terminals open with services already running. No live installs, no live startups, no live config edits during the demo.

---

# SECTION 6 — FULL 11-STEP LIVE DEMONSTRATION SCRIPT

---

## ════════════════════════════════════════════
## STEP 1 — TOPOLOGY AND IP/SERVICE INVENTORY
## ════════════════════════════════════════════

### PURPOSE
Establish what the project is and how the four machines connect before any live commands.
This is the orientation — the audience must understand the architecture before seeing traffic.

### SCREEN STATE BEFORE STARTING
- **Projected:** Mac 4 / Vaidehi
- **Visible:** `CN_PROJECT_LIVE_CONFIG.md` open in editor OR topology diagram
- **All services running:** dnsmasq on Mac 1, nginx on Mac 2, Backend A on Mac 3, Backend B on Mac 4
- **All terminals pre-opened** on each Mac

### TEAM POSITIONS
- **Om:** Mac 1 ready. dnsmasq running. Terminal open showing `pgrep -fl dnsmasq` output.
- **Aditya:** Mac 2 ready. nginx running. Wireshark closed for now. Terminal open.
- **Krishiv:** Mac 3 ready. Backend A running (`python3 backend_a/server.py` in terminal).
- **Vaidehi:** Mac 4 projected. Speaks the entire segment. `CN_PROJECT_LIVE_CONFIG.md` visible.

### SPEAKER: Vaidehi

### WORD-FOR-WORD DIALOGUE

"Good morning. My name is Vaidehi and I am presenting on behalf of Team 1.
Our project is called Private Network Service Platform.
The core idea is simple: the application itself is not the point — the network is the point.

We have built a complete private network from scratch using four MacBooks connected to the same Wi-Fi.
Every component you would find in a real production system — DNS, a load balancer, TLS, backend servers —
we have configured and running live right now.

Let me walk you through the architecture before we start the live demo.

[SCREEN: Point to topology or live config file]

We have four machines.

Mac 1 belongs to Om. His IP is 10.7.15.236.
Om runs our private DNS server using a tool called dnsmasq.
His machine is the directory service for our network —
it is the only thing on this LAN that knows what app.team1.test means.

Mac 2 belongs to Aditya. His IP is 10.7.17.151.
Aditya runs nginx — our edge server.
nginx does three things simultaneously:
it terminates TLS so all HTTPS traffic is decrypted here,
it acts as a reverse proxy forwarding requests to the backends,
and it load-balances across two backend servers using round-robin.
This is the only machine the outside world ever talks to directly.

Mac 3 belongs to Krishiv. His IP is 10.7.16.201.
Krishiv runs Backend A — a lightweight HTTP REST server on port 3001.
It returns JSON and identifies itself with the header X-Backend: A.

I am Vaidehi on Mac 4 at IP 10.7.2.96.
I run Backend B on port 3002, and my machine is also the test client for this demonstration.
Backend B identifies itself with X-Backend: B.

All four machines are on the same private network: 10.7.0.0 slash 19.
The subnet mask is 255.255.224.0 and the gateway is 10.7.0.1.

The request flow works like this.
A client types app.team1.test.
The client does not know what IP that is — so it first asks Om's DNS server.
Om's dnsmasq replies: that name maps to 10.7.17.151 — Aditya's machine.
The client then creates a TCP connection to Aditya's machine on port 8443.
A TLS handshake happens — the connection becomes encrypted.
nginx on Aditya's machine receives the decrypted HTTP request.
nginx picks a backend — either Krishiv's Backend A at 10.7.16.201:3001
or my Backend B at 10.7.2.96:3002 — and forwards the request.
The backend responds, nginx passes the response back to the client,
and the client sees a JSON reply over HTTPS.

The client never directly contacts Backend A or Backend B.
It only ever talks to nginx. The backend IPs are hidden.

That is the full architecture. Let us now verify it is all live."

### FACULTY INTERRUPTION / VIVA QUESTIONS

Q: Why do you use nginx instead of letting the client talk directly to the backends?
A: Two reasons. First, the client should not need to know which backend to contact — nginx abstracts that. Second, nginx handles TLS termination centrally, so the backends can stay simple HTTP servers. In production this is exactly what a cloud load balancer does.

Q: What is the difference between a reverse proxy and a forward proxy?
A: A forward proxy sits in front of clients and acts on their behalf — like a VPN or corporate proxy. A reverse proxy sits in front of servers and acts on the server's behalf. The client talks to the reverse proxy thinking it is the server. nginx here is a reverse proxy.

Q: Why do you use the .test domain and not .local or .com?
A: .local conflicts with macOS Bonjour mDNS — it causes resolution loops on macOS. .com is a real public domain we do not own. .test is an IANA-reserved namespace specifically for local testing. It will never be delegated publicly.

Q: What is 10.7.0.0/19? What does the /19 mean?
A: /19 means the first 19 bits of the IP address are the network portion. That leaves 13 bits for hosts, giving 8190 usable host addresses. Our four machines all have IPs in the range 10.7.0.1 to 10.7.31.254, confirming they are all on the same subnet.

### FAILURE / RECOVERY
If a service is not running when the demo starts:
- dnsmasq: Om runs `sudo /opt/homebrew/sbin/dnsmasq -C ~/Documents/CN_Project/config/dnsmasq.conf`
- nginx: Aditya runs `brew services start nginx`
- Backend A: Krishiv runs `python3 backend_a/server.py` from the project directory
- Backend B: Vaidehi runs `python3 backend_b/server.py` from the project directory

---

## ════════════════════════════════════════════
## STEP 2 — CONFIRM ALL MACHINES ARE ON THE PRIVATE LAN
## ════════════════════════════════════════════

### PURPOSE
Prove that all four machines are reachable on the same network.
No higher-layer service (DNS, HTTPS, backends) can work if basic IP connectivity does not exist.
This establishes the physical and network foundation.

### SCREEN STATE
- **Projected:** Mac 4 / Vaidehi — Terminal
- **Other Macs:** Each has a terminal open, watching for ping results

### TEAM POSITIONS
- **Om:** Terminal open on Mac 1. Will run ping on his machine when Vaidehi gives the cue.
- **Aditya:** Terminal open on Mac 2. Will confirm his IP on cue.
- **Krishiv:** Terminal open on Mac 3. Will confirm his IP on cue.
- **Vaidehi:** Speaks and runs ping commands from Mac 4.

### SPEAKER: Vaidehi

### WORD-FOR-WORD DIALOGUE

"Let me now confirm that all four machines are on the same private LAN.
Everything else depends on this working first.

I will start by checking my own IP address."

[SCREEN: Mac 4 / Vaidehi terminal]
[ACTION: Type:]
```
ifconfig en0 | grep "inet "
```
[EXPECTED OUTPUT:]
```
inet 10.7.2.96 netmask 0xffffe000 broadcast 10.7.31.255
```

"My IP is 10.7.2.96 and the broadcast address is 10.7.31.255.
The subnet mask 0xffffe000 is 255.255.224.0 in decimal, which is a /19 prefix.
All four of our machines are within this range.

Now let me ping each of the other three machines to confirm they are reachable."

[ACTION: Type:]
```
ping -c 3 10.7.15.236
```
[EXPECTED OUTPUT:]
```
3 packets transmitted, 3 packets received, 0.0% packet loss
```

"10.7.15.236 — that is Om's Mac 1, our DNS server. Reachable.

[ACTION: Type:]
```
ping -c 3 10.7.17.151
```
[EXPECTED OUTPUT:]
```
3 packets transmitted, 3 packets received, 0.0% packet loss
```

10.7.17.151 — that is Aditya's Mac 2, our nginx edge. Reachable.

[ACTION: Type:]
```
ping -c 3 10.7.16.201
```
[EXPECTED OUTPUT:]
```
3 packets transmitted, 3 packets received, 0.0% packet loss
```

10.7.16.201 — that is Krishiv's Mac 3, Backend A. Reachable.

All three pings succeeded. All four machines are on the same LAN and can communicate at the IP layer.
This is Layer 3 connectivity — no DNS, no TCP, no TLS involved yet.
Just raw IP packets crossing the Wi-Fi network.

The gateway for this network is 10.7.0.1. Any traffic that needs to leave this subnet
would go through that gateway. But for our project, all traffic stays within the 10.7.0.0/19 LAN —
there is no internet involved."

### FACULTY INTERRUPTION / VIVA QUESTIONS

Q: What does ping actually do? Which protocol does it use?
A: Ping uses ICMP — Internet Control Message Protocol. It sends an Echo Request packet to the target IP and expects an Echo Reply back. It operates at Layer 3 and tests basic IP reachability without any port or service involved.

Q: What is a subnet mask and why does it matter here?
A: A subnet mask defines which part of an IP address is the network portion and which is the host portion. With /19 or 255.255.224.0, the first 19 bits are the network — so all IPs from 10.7.0.0 to 10.7.31.255 are on the same subnet. Machines on the same subnet can communicate directly without going through a router.

Q: What is the gateway 10.7.0.1 used for?
A: When a machine wants to reach an IP that is outside its own subnet, it sends the packet to the gateway. The gateway — which is a router — then forwards it towards the destination. Since all our machines are within 10.7.0.0/19, they communicate directly and never actually use the gateway during our demo.

Q: Could you run this project on a hotspot? On a university Wi-Fi?
A: Yes, on a hotspot all machines join the same private LAN. On university Wi-Fi it depends on whether client isolation is enabled. If the university network blocks direct machine-to-machine traffic, the pings would fail and we would need our own hotspot.

### FAILURE / RECOVERY
If ping fails to a specific machine:
- Check that machine's Wi-Fi is connected: `ifconfig en0 | grep inet`
- Check for macOS firewall blocking ICMP: System Settings → Firewall → turn off temporarily
- Verify same subnet: all IPs must be in 10.7.0.0 – 10.7.31.255

---

## ════════════════════════════════════════════
## STEP 3 — RESOLVE THE PRIVATE DOMAIN FROM A CLIENT
## ════════════════════════════════════════════

### PURPOSE
Prove that the private DNS server on Mac 1 correctly resolves `app.team1.test` to Mac 2's IP.
This is Task B of the project. DNS is the first step in every HTTPS request.
Without this, the client cannot even know which machine to contact.

### SCREEN STATE
- **Projected:** Mac 4 / Vaidehi — Terminal

### TEAM POSITIONS
- **Om:** dnsmasq running on Mac 1. No action needed unless Vaidehi asks to show the config.
- **Aditya:** Idle. nginx running.
- **Krishiv:** Idle. Backend A running.
- **Vaidehi:** Speaks and types on Mac 4.

### SPEAKER: Vaidehi

### WORD-FOR-WORD DIALOGUE

"Now let me demonstrate the private DNS server.

DNS — Domain Name System — is a directory service.
When a client wants to connect to app.team1.test,
it does not know the IP address. It asks a DNS server.
Our DNS server is running on Om's Mac 1 at 10.7.15.236,
using a lightweight tool called dnsmasq.

Let me first confirm that my Mac is configured to use Om's DNS server."

[SCREEN: Mac 4 / Vaidehi terminal]
[ACTION: Type:]
```
networksetup -getdnsservers Wi-Fi
```
[EXPECTED OUTPUT:]
```
10.7.15.236
```

"My DNS is pointing to 10.7.15.236 — Om's machine.
Every DNS query from my Mac goes to Om's dnsmasq first.

Now let me do the lookup."

[ACTION: Type:]
```
dig app.team1.test +short
```
[EXPECTED OUTPUT:]
```
10.7.17.151
```

"app.team1.test resolved to 10.7.17.151. That is Aditya's Mac 2 — our nginx edge.
The resolution came from Om's private dnsmasq. This domain does not exist on any public DNS server.

To prove that, let me query Google's public DNS instead."

[ACTION: Type:]
```
dig app.team1.test @8.8.8.8 +short
```
[EXPECTED OUTPUT: empty — no output]

"Nothing. Google has no record for app.team1.test.
It only exists in our private dnsmasq configuration on Om's Mac 1.

Now I want to be precise about something important.
DNS only answered the question: where is app.team1.test?
It told us: go to 10.7.17.151.
DNS is now completely finished. It plays no further role in this request.
The actual TCP connection, TLS handshake, and HTTP exchange
happen directly between my Mac and Aditya's Mac — DNS is not involved in any of that.

Also — notice we use .test, not .local.
macOS uses .local for its own Bonjour service discovery.
If we used .local, our DNS records would conflict with macOS mDNS
and cause unpredictable resolution failures.
.test is an IANA-reserved namespace for exactly this kind of local testing."

### FACULTY INTERRUPTION / VIVA QUESTIONS

Q: What protocol does DNS use and on which port?
A: DNS primarily uses UDP on port 53. It can also use TCP on port 53 for large responses that exceed the 512-byte UDP limit, or for zone transfers. In our project, dnsmasq handles both.

Q: What is the difference between DNS resolution and making a connection?
A: DNS resolution is a lookup — the client asks a directory for an IP address and gets an answer. Making a connection is a separate act — the client uses that IP to create a TCP socket to the server. DNS ends the moment the IP is returned. TCP begins after DNS is done.

Q: What is dnsmasq and why did you choose it?
A: dnsmasq is a lightweight DNS forwarder and DHCP server. It is easy to configure on macOS, supports custom A records for private domains, and needs only a simple config file. It is the standard recommendation for this kind of project.

Q: What is an A record in DNS?
A: An A record maps a domain name to an IPv4 address. Our dnsmasq config has: address=/app.team1.test/10.7.17.151 — that is the A record saying app.team1.test is at 10.7.17.151.

Q: What would happen if Om's dnsmasq was not running when we make this request?
A: The dig query would fail — it would return SERVFAIL or time out. Then when the browser tries to open https://app.team1.test, it would show "Server not found" — not because the server is down, but because the client cannot find the IP. DNS failure stops everything before TCP even begins.

### FAILURE / RECOVERY
If `dig app.team1.test +short` returns nothing or NXDOMAIN:
- Verify dnsmasq is running on Mac 1: `pgrep -fl dnsmasq`
- If not running: `sudo /opt/homebrew/sbin/dnsmasq -C ~/Documents/CN_Project/config/dnsmasq.conf`
- Verify Mac 4 DNS setting: `networksetup -getdnsservers Wi-Fi` must show 10.7.15.236
- Test directly: `dig app.team1.test @10.7.15.236 +short` — if this works, the issue is Mac 4's DNS setting, not dnsmasq

---

## ════════════════════════════════════════════
## STEP 4 — OPEN THE SERVICE OVER HTTPS USING THE DOMAIN NAME
## ════════════════════════════════════════════

### PURPOSE
Prove end-to-end HTTPS access using only the domain name — no IP in the URL, no -k bypass.
This demonstrates: DNS → TCP → TLS → nginx → backend → response, all in one command.
This is the single most important demo command in Phase 1.

### SCREEN STATE
- **Projected:** Mac 4 / Vaidehi — Terminal

### TEAM POSITIONS
- **Om:** Idle. dnsmasq running.
- **Aditya:** Idle. nginx running.
- **Krishiv:** Idle. Backend A running.
- **Vaidehi:** Speaks and types on Mac 4.

### SPEAKER: Vaidehi

### WORD-FOR-WORD DIALOGUE

"Now the full end-to-end demonstration.

I am going to make an HTTPS request using only the domain name.
No IP address in the URL. No -k flag. The certificate is trusted on my machine.
This is exactly how a real user or application would access our service.

Watch."

[SCREEN: Mac 4 / Vaidehi terminal]
[ACTION: Type:]
```
curl -s https://app.team1.test:8443/api/status
```
[EXPECTED OUTPUT:]
```
{"backend": "A", "status": "ok"}
```
or
```
{"backend": "B", "status": "ok"}
```

"It worked. HTTPS, domain name, trusted certificate, no warnings, no shortcuts.

Let me now show the full response headers so we can see exactly what happened at each layer."

[ACTION: Type:]
```
curl -sI https://app.team1.test:8443/api/status
```
[EXPECTED OUTPUT:]
```
HTTP/1.1 200 OK
Server: nginx/1.31.6
X-Backend: A
Cache-Control: max-age=60
ETag: "72db076608216f33"
Content-Type: application/json
```

"Several things to point out here.

The status is 200 OK — the request succeeded.

The Server header says nginx — that is Aditya's Mac 2 responding.
I am not directly talking to a backend. My entire conversation is with nginx.

X-Backend tells us which backend actually handled this request behind nginx.
Right now it says A — that is Krishiv's machine at 10.7.16.201:3001.

Cache-Control: max-age=60 tells any client that this response is fresh for 60 seconds.
I will demonstrate caching in more detail shortly.

Now let me also show the TLS details — proving the certificate is valid and trusted."

[ACTION: Type:]
```
curl -sv https://app.team1.test:8443/api/status 2>&1 | grep -E "TLSv|subject|issuer|cipher|HTTP/"
```
[EXPECTED OUTPUT:]
```
* TLSv1.3 (OUT), TLS handshake, ...
* SSL connection using TLSv1.3 / TLS_AES_256_GCM_SHA384
* Server certificate:
*  subject: CN=app.team1.test
*  issuer: CN=app.team1.test
< HTTP/1.1 200 OK
```

"TLS 1.3 — the latest version. The certificate subject is app.team1.test.
The certificate was issued specifically for our domain by Aditya on Mac 2
and installed in my Mac's trust store.
That is why there is no certificate warning — it is genuinely trusted, not bypassed.

Let me now walk through what happened in this single command.

First, my Mac sent a DNS query to Om's machine to resolve app.team1.test.
Om's dnsmasq replied with 10.7.17.151.
My Mac then opened a TCP connection to 10.7.17.151 on port 8443 — three-way handshake.
Then TLS negotiation began: ClientHello, ServerHello, Certificate, key exchange, Finished.
Then my encrypted HTTP GET request travelled through the TLS tunnel to nginx.
nginx decrypted it, selected a backend using round-robin, forwarded the request as plain HTTP.
The backend responded, nginx encrypted the response and sent it back to me.

That is DNS, TCP, TLS, HTTP, reverse proxy, and load balancing — all in one curl command."

### FACULTY INTERRUPTION / VIVA QUESTIONS

Q: What is TLS termination? Why does it happen at nginx and not at the backend?
A: TLS termination means nginx decrypts the HTTPS traffic and communicates with the backends over plain HTTP. The backends do not need TLS certificates or TLS configuration. This is standard practice — centralise security at the edge, keep backends simple. In our case, the backend-to-nginx communication is on a private LAN, so plain HTTP is acceptable.

Q: Why port 8443 instead of 443?
A: macOS requires root access to bind to ports below 1024. Homebrew nginx runs as a normal user. Port 8443 is the standard alternative for HTTPS in development environments. The project spec explicitly allows this with no mark deduction.

Q: What does the -k flag in curl do and why are you not using it?
A: The -k flag tells curl to skip certificate validation — to trust any certificate regardless of who issued it. Using -k means you are not actually testing TLS security. The project requirement is to demonstrate real certificate trust. Our certificate is installed in the macOS Keychain, so curl trusts it without -k.

Q: What is SNI — Server Name Indication?
A: SNI is a TLS extension where the client includes the hostname it is connecting to inside the ClientHello message — before the TLS handshake is complete. This lets nginx know which certificate to send back, because one nginx instance could serve multiple domains. In our ClientHello, SNI = app.team1.test.

Q: What is the difference between HTTP and HTTPS?
A: HTTP is plaintext — anyone on the network can read the headers and body. HTTPS is HTTP inside a TLS tunnel — the entire HTTP exchange is encrypted. The only visible parts in a Wireshark capture are the IP and TCP headers and the TLS record sizes. The HTTP method, URL, headers, and body are all hidden.

### FAILURE / RECOVERY
If curl times out (exit code 28):
- Check nginx is running: `brew services list | grep nginx` on Aditya's Mac
- Test nginx locally: `curl -sk https://127.0.0.1:8443/health` on Mac 2
- Check backends are up: `curl -s http://10.7.16.201:3001/api/status` and `curl -s http://10.7.2.96:3002/api/status`

If `curl: (60) SSL certificate problem: self signed certificate`:
- The cert is not trusted on Mac 4 — run: `sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain /path/to/team1.test.crt`

---

## ════════════════════════════════════════════
## STEP 5 — SHOW LOAD BALANCING ACROSS BOTH BACKENDS
## ════════════════════════════════════════════

### PURPOSE
Prove that nginx distributes requests across both backends.
The client always talks to the same domain and same IP — but different backends respond.
This is round-robin load balancing.

### SCREEN STATE
- **Projected:** Mac 4 / Vaidehi — Terminal

### TEAM POSITIONS
- **Om:** Idle. dnsmasq running.
- **Aditya:** Idle. nginx running.
- **Krishiv:** Backend A running. Watching his terminal to see incoming requests logged.
- **Vaidehi:** Speaks and types on Mac 4.

### SPEAKER: Vaidehi

### WORD-FOR-WORD DIALOGUE

"Now I will demonstrate round-robin load balancing.

nginx maintains an upstream pool — a list of backends.
For every incoming request, it picks the next backend in the list, cycling through them in order.
This is called round-robin.

Let me send 8 requests to the same URL and watch which backend responds each time."

[SCREEN: Mac 4 / Vaidehi terminal]
[ACTION: Type:]
```
for i in {1..8}; do
  echo -n "Request $i: "
  curl -s https://app.team1.test:8443/api/status
  echo
done
```
[EXPECTED OUTPUT:]
```
Request 1: {"backend": "A", "status": "ok"}
Request 2: {"backend": "B", "status": "ok"}
Request 3: {"backend": "A", "status": "ok"}
Request 4: {"backend": "B", "status": "ok"}
Request 5: {"backend": "A", "status": "ok"}
Request 6: {"backend": "B", "status": "ok"}
Request 7: {"backend": "A", "status": "ok"}
Request 8: {"backend": "B", "status": "ok"}
```

"You can see the responses alternating between Backend A and Backend B.
Backend A is Krishiv's machine at 10.7.16.201:3001.
Backend B is my machine at 10.7.2.96:3002.

Every single request went to the same domain — app.team1.test.
My machine never changed the URL. But nginx is distributing the load between two different servers.

The client has no knowledge of how many backends exist or what their IPs are.
It only ever talks to nginx. The backend topology is completely hidden.

Let me also confirm using the response headers which backend served each request."

[ACTION: Type:]
```
for i in {1..4}; do
  echo -n "Request $i backend: "
  curl -sI https://app.team1.test:8443/api/status | grep "X-Backend"
done
```
[EXPECTED OUTPUT:]
```
Request 1 backend: X-Backend: A
Request 2 backend: X-Backend: B
Request 3 backend: X-Backend: A
Request 4 backend: X-Backend: B
```

"The X-Backend header is set by each backend server — not by nginx.
nginx passes it through using the proxy_pass_header directive.
This is how we can see which physical machine handled each request."

### FACULTY INTERRUPTION / VIVA QUESTIONS

Q: What is round-robin load balancing?
A: Round-robin distributes requests sequentially across all available backends in order. Request 1 goes to Backend A, request 2 to Backend B, request 3 back to A, and so on. It assumes all backends have equal capacity and treats every request as equal weight.

Q: What is the nginx upstream block?
A: The upstream block in nginx defines a pool of backend servers. In our config it is: upstream backend_nodes { server 10.7.16.201:3001; server 10.7.2.96:3002; }. nginx round-robins across these by default.

Q: How does the client not know it is talking to two different backends?
A: Because the client only ever connects to nginx at 10.7.17.151:8443. nginx makes a separate internal connection to whichever backend it chooses. The client never sees the backend IPs. This is the reverse proxy pattern.

Q: What would happen if we used least_conn instead of round-robin?
A: With least_conn, nginx would send each new request to whichever backend currently has the fewest active connections. This is better when requests have unequal processing times. Round-robin works well when requests are roughly equal in cost.

Q: Why does the alternation not always appear perfectly 1-2-1-2?
A: nginx's round-robin is connection-based. If curl reuses a keep-alive connection or the timing of responses affects scheduling, the pattern may vary. In our setup with new connections per curl call and short responses, it appears close to perfect alternation.

### FAILURE / RECOVERY
If all responses show only A or only B:
- One backend is down. Check both: `curl -s http://10.7.16.201:3001/api/status` and `curl -s http://10.7.2.96:3002/api/status`
- Restart whichever is down before continuing
If responses show `502 Bad Gateway`:
- Both backends are down. Start both before continuing.


---

## ════════════════════════════════════════════
## STEP 6 — WIRESHARK EVIDENCE OF DNS, TCP, AND TLS
## ════════════════════════════════════════════

### PURPOSE
Show packet-level proof that every protocol layer is working.
Wireshark is the evidence layer — it lets us see DNS queries, TCP handshakes, and TLS handshakes
as actual network packets, not just inferred from curl output.
This also proves HTTPS encryption is real — the payload is invisible.

### SCREEN STATE BEFORE STARTING
- **Projected:** SWITCH TO Mac 2 / Aditya
- **Aditya has open:** Wireshark with `evidence/script7/pcap/script7_capture.pcapng` already loaded
- **All filters cleared** — Aditya starts at the full unfiltered packet list

### TEAM POSITIONS
- **Om:** Idle. dnsmasq running.
- **Aditya:** Controls Wireshark on Mac 2. Does NOT speak. Applies filters exactly when Vaidehi says the cue phrase.
- **Krishiv:** Idle. Backend A running.
- **Vaidehi:** Speaks the entire segment from her seat. Does NOT touch keyboard during this segment.

### SPEAKER: Vaidehi

### WORD-FOR-WORD DIALOGUE

"Now I want to show you every layer of that request at the packet level using Wireshark.

[CUE: Vaidehi says] Aditya, please take the screen.

[SCREEN HANDOFF → MAC 2 / ADITYA]

We captured this traffic on Aditya's Mac 2 — the edge machine where all traffic passes through.
The capture file is saved in our evidence folder.
What you can see right now is the raw unfiltered packet list from that capture.

Let me walk you through the four layers one by one.

---

LAYER 1 — DNS.

Aditya, please apply the filter: dns

[ADITYA applies filter: dns in Wireshark display filter bar]

You can now see the DNS exchange — two packets.
The first packet is the DNS query.
It goes from the client IP to 10.7.15.236 on port 53 over UDP.
The client is asking: what is the IP address of app.team1.test?

The second packet is the DNS response from Om's dnsmasq.
It comes back from 10.7.15.236 to the client.
The answer section says: app.team1.test has address 10.7.17.151.

Notice the protocol is UDP. DNS almost always uses UDP because it is fast and the messages are small.
Port 53 is the standard DNS port.

This entire DNS exchange happened before any TCP connection was made.
DNS is purely a lookup. It does not establish a connection.
It just tells the client: go to 10.7.17.151.

---

LAYER 2 — TCP Three-Way Handshake.

Aditya, please filter: tcp.port == 8443

[ADITYA applies filter: tcp.port == 8443]

Now you can see the TCP handshake — three packets in sequence.

The first packet has the SYN flag set. The source is the client — Mac 4.
The destination is 10.7.17.151 port 8443 — that is Aditya's nginx.
The client is saying: I want to establish a connection.
Notice the source port is a high ephemeral number — something like 54321.
This is a randomly assigned port chosen by the client's operating system.
The destination port is 8443 — the well-known port for our HTTPS service.

The second packet has SYN and ACK set. It comes from nginx.
nginx is saying: I received your SYN, I accept, here is my sequence number.

The third packet has only ACK set. The client confirms the handshake.
Connection established.

At this point, no HTTP or TLS data has been sent.
This is a pure transport-layer event — establishing a reliable ordered channel
before anything else can happen.

---

LAYER 3 — TLS Handshake.

Aditya, please filter: tls

[ADITYA applies filter: tls]

Now you can see the TLS handshake packets.

The first TLS record is the ClientHello from the client to nginx.
If you expand that packet and look at the extensions section,
you will find an extension called Server Name Indication — SNI.
The SNI value is app.team1.test.

This is important. The client is telling nginx which domain it wants
before the TLS session is fully established.
This allows nginx to select the correct certificate to send back —
because in theory one nginx could serve many different domains.

The next record is the ServerHello plus the Certificate.
nginx sends back TLS 1.3 parameters and the team1.test.crt certificate.
The client verifies this certificate against its trusted store.
Because we installed the certificate in Mac 4's Keychain, it passes.

After the key exchange, both sides send Finished records.
The TLS session is now fully established.
Everything from this point is encrypted.

---

LAYER 4 — Encrypted Application Data.

Aditya, please filter: tls.record.content_type == 23

[ADITYA applies filter: tls.record.content_type == 23]

Content type 23 means Application Data in TLS — this is the actual HTTP traffic.

You can see packets flowing in both directions between the client and nginx.
Each packet shows only a length in bytes.
The content is completely opaque — you cannot see the HTTP method, URL, headers, or body.

This is the proof that HTTPS encryption is working.
If this were plain HTTP, Wireshark would show the full request and response in readable text.
Because TLS is encrypting everything, all we see are encrypted blobs.

The only way we know what is inside is from the curl output we showed earlier.

To summarise what we just saw:
DNS on UDP port 53 — resolved the name.
TCP three-way handshake on port 8443 — established the connection.
TLS handshake — secured the channel.
Application data — encrypted HTTP exchange.
Every layer. Every protocol. All visible at the packet level.

[CUE: Vaidehi says] Aditya, thank you. I will take the screen back.

[SCREEN HANDOFF → MAC 4 / VAIDEHI]"

### ADITYA'S CUE CARD (Wireshark filters in order)
1. `dns`
2. `tcp.port == 8443`
3. `tls`
4. `tls.record.content_type == 23`

Apply each filter exactly when Vaidehi says the phrase. Do not skip ahead.

### FACULTY INTERRUPTION / VIVA QUESTIONS

Q: What is an ephemeral port?
A: An ephemeral port is a temporary high-numbered port (typically 49152–65535) that the client OS assigns randomly for each outgoing TCP connection. The client uses this as its source port. The server always listens on a fixed well-known port — 8443 in our case. After the connection closes, the ephemeral port is released and can be reused.

Q: What is SNI and why is it needed?
A: Server Name Indication is a TLS extension that lets the client tell the server which hostname it wants during the ClientHello — before the certificate is sent. Without SNI, a server with multiple domains would not know which certificate to present. In our case nginx uses SNI to serve the team1.test certificate.

Q: Why can you not see the HTTP payload in Wireshark even though you can see the packet?
A: Because TLS encrypts the entire HTTP layer. Wireshark can see the IP and TCP headers because those are in plaintext — they are needed for routing. But the TLS record payload is encrypted with the session key that was negotiated during the handshake. Only the client and nginx have that key.

Q: What is content type 23 in TLS?
A: TLS records have a type field. Type 20 is ChangeCipherSpec, type 21 is Alert, type 22 is Handshake, and type 23 is Application Data. Application Data records carry the actual encrypted payload — in our case the HTTP request and response.

Q: What is the difference between TCP SYN and TCP SYN-ACK?
A: SYN is the first packet sent by the client to initiate a connection — it contains the client's initial sequence number. SYN-ACK is the server's reply — it acknowledges the client's sequence number and includes its own. The final ACK from the client completes the handshake. After this three-packet exchange, both sides have synchronised sequence numbers and the connection is established.

Q: Where does TLS fit in the OSI model?
A: TLS sits between the Application layer (Layer 7) and the Transport layer (Layer 4). Some models place it at Layer 6 (Presentation) because it handles encryption and formatting. It runs on top of TCP and below HTTP.

### FAILURE / RECOVERY
If Wireshark shows no packets or empty capture:
- Use the saved pcap file from `evidence/script7/pcap/script7_capture.pcapng`
- Do not do a live capture during the demo — the saved capture is reliable and already verified
If the filter shows no matching packets:
- Check the filter syntax — Wireshark filters are case-sensitive
- `dns` must be lowercase
- `tls.record.content_type == 23` must have spaces around `==`

---

## ════════════════════════════════════════════
## STEP 7 — HTTP HEADERS AND CACHING BEHAVIOR
## ════════════════════════════════════════════

### PURPOSE
Prove that HTTP caching is implemented using Cache-Control and ETag headers.
Show a conditional request that returns 304 Not Modified — proving the client can
validate its cached copy without receiving the full response body again.

### SCREEN STATE
- **Projected:** Mac 4 / Vaidehi — Terminal (back from Wireshark handoff)

### TEAM POSITIONS
- **Om:** Idle. dnsmasq running.
- **Aditya:** Idle. nginx running. Wireshark can be closed.
- **Krishiv:** Idle. Backend A running.
- **Vaidehi:** Speaks and types on Mac 4.

### SPEAKER: Vaidehi

### WORD-FOR-WORD DIALOGUE

"Now let me demonstrate HTTP caching.

Both backends implement two caching mechanisms.
The first is Cache-Control — a header that tells the client how long to keep the response fresh.
The second is ETag — a fingerprint of the response content that allows conditional requests.

Let me show the caching headers on a normal response."

[SCREEN: Mac 4 / Vaidehi terminal]
[ACTION: Type:]
```
curl -sI https://app.team1.test:8443/api/status
```
[EXPECTED OUTPUT — point to these specific headers:]
```
HTTP/1.1 200 OK
X-Backend: A
Cache-Control: max-age=60
ETag: "72db076608216f33"
Content-Type: application/json
Content-Length: 32
```

"Two headers to focus on.

Cache-Control: max-age=60.
This tells the client — and any intermediate proxy or CDN in a real network —
that this response is valid for 60 seconds.
Within that 60-second window, the client does not need to make any network request at all.
It serves the cached response locally with zero latency and zero bandwidth.

ETag: 72db076608216f33.
This is a fingerprint — specifically the MD5 hash of the response body.
The client stores this ETag alongside the cached response.
When the cache expires, instead of fetching the full response again,
the client can ask the server: is your current version still 72db076608216f33?

That question is called a conditional request. Let me demonstrate it."

[ACTION: Type:]
```
curl -sI -H 'If-None-Match: "72db076608216f33"' https://app.team1.test:8443/api/status
```
[EXPECTED OUTPUT:]
```
HTTP/1.1 304 Not Modified
X-Backend: A
Cache-Control: max-age=60
ETag: "72db076608216f33"
```

"304 Not Modified.

The server confirmed: your cached copy is still the current version.
Notice what is missing from this response — there is no body.
No Content-Length. No JSON payload. Zero bytes of content transferred.

The client now resets its cache timer and continues using the cached copy.

This is the three-stage caching model.
Stage one: fresh cache hit — the client serves from local cache, no network call at all.
Stage two: conditional request — the cache has expired, the client checks with the server.
If nothing changed, it gets 304 and keeps the cache. Minimal network cost.
Stage three: full request — the server's content has changed, a full 200 response is returned.

These headers survive all the way through nginx.
nginx does not strip Cache-Control or ETag — they pass from the backend to the client intact.

One more technical note — Backend A uses a content-derived ETag.
It computes the MD5 hash of the response body and uses the first 16 hex characters as the ETag.
If the response body ever changes, the ETag automatically updates.
No manual constant to maintain."

### FACULTY INTERRUPTION / VIVA QUESTIONS

Q: What is the difference between Cache-Control: max-age and Expires?
A: max-age is a relative time in seconds from when the response was received. Expires is an absolute date-time. max-age is preferred in HTTP/1.1 because it is not affected by clock differences between client and server.

Q: What is an ETag?
A: ETag stands for Entity Tag. It is a unique identifier for a specific version of a resource. When the server returns a response, it includes an ETag. When the client's cache expires, it sends the ETag back to the server in an If-None-Match header. If the resource has not changed, the server returns 304. If it has changed, the server returns 200 with the new content and a new ETag.

Q: What is 304 Not Modified?
A: 304 is an HTTP status code meaning the resource has not changed since the version identified by the ETag or Last-Modified the client sent. The server sends only headers — no body. The client continues using its cached copy.

Q: What is Cache-Control: no-store?
A: no-store tells the client and all proxies never to cache this response at all. Our backend uses no-store on error responses — 404s and 500s — so that a transient error is never cached and served to future clients.

Q: Does nginx cache the backend responses in our setup?
A: No. nginx's proxy_cache directive is not configured in our setup. nginx acts as a pure reverse proxy — it forwards requests and responses without caching. The caching in our demo is client-side only, demonstrated through the If-None-Match conditional request mechanism.

### FAILURE / RECOVERY
If the 304 response does not appear and you get 200 instead:
- The request may have hit Backend B (ETag is `"backend-b-v1"` on Backend B, not `"72db076608216f33"`)
- Force the request to Backend A by running several requests until X-Backend: A appears, note the ETag, then use that ETag in the If-None-Match header
- Alternatively use the Backend A ETag directly: `curl -sI -H 'If-None-Match: "72db076608216f33"' http://10.7.16.201:3001/api/status` (direct to Backend A)

---

## ════════════════════════════════════════════
## STEP 8 — FAIL ONE BACKEND AND PROVE SERVICE CONTINUES
## ════════════════════════════════════════════

### PURPOSE
Prove that the service remains available when one backend fails.
nginx detects that Backend A is unreachable and routes all traffic to Backend B.
This demonstrates basic resilience at the application layer.

### SCREEN STATE
- **Projected:** Mac 4 / Vaidehi — Terminal

### TEAM POSITIONS
- **Om:** Idle. dnsmasq running.
- **Aditya:** Idle. nginx running. Watching nginx error log if possible: `tail -f /opt/homebrew/var/log/nginx/team_error.log`
- **Krishiv:** Backend A terminal visible and ready to stop on cue. Watching Vaidehi.
- **Vaidehi:** Speaks and types on Mac 4.

### SPEAKER: Vaidehi

### WORD-FOR-WORD DIALOGUE

"Now the failure demonstration.

Phase 1 requires us to prove the system behaves correctly under controlled failures.
I will stop Backend A — Krishiv's server — and show that the service continues through Backend B.

First, let me confirm both backends are currently serving by sending a few requests."

[SCREEN: Mac 4 / Vaidehi terminal]
[ACTION: Type:]
```
for i in {1..4}; do
  echo -n "Request $i: "
  curl -s https://app.team1.test:8443/api/status
  echo
done
```
[EXPECTED OUTPUT — alternating A and B:]
```
Request 1: {"backend": "A", "status": "ok"}
Request 2: {"backend": "B", "status": "ok"}
Request 3: {"backend": "A", "status": "ok"}
Request 4: {"backend": "B", "status": "ok"}
```

"Good. Both A and B are serving.

[CUE → KRISHIV] Krishiv, please stop Backend A now.

[KRISHIV: In his terminal, presses Ctrl+C to stop python3 server.py on Mac 3]
[WAIT 3 seconds for Krishiv to confirm Backend A is stopped]

Backend A is now down. Let me send requests and see what happens."

[ACTION: Type:]
```
for i in {1..6}; do
  echo -n "Request $i: "
  curl -s https://app.team1.test:8443/api/status
  echo
done
```
[EXPECTED OUTPUT — all from Backend B:]
```
Request 1: {"backend": "B", "status": "ok"}
Request 2: {"backend": "B", "status": "ok"}
Request 3: {"backend": "B", "status": "ok"}
Request 4: {"backend": "B", "status": "ok"}
Request 5: {"backend": "B", "status": "ok"}
Request 6: {"backend": "B", "status": "ok"}
```

"All six responses came from Backend B.
DNS is still working. nginx is still working. TLS is still working.
Backend A is unreachable — but the service never interrupted.

Here is exactly what happened.
nginx tried to forward the request to Backend A at 10.7.16.201:3001.
The TCP connection attempt timed out or was refused because nothing was listening on that port.
nginx then marked Backend A as temporarily unavailable and sent the request to Backend B instead.
The client received a successful 200 response and never saw any error.

This is the nginx passive health check — it marks a backend as failed after failed connection attempts
and stops sending it requests until it starts responding again.

Let me now restart Backend A and verify normal load balancing resumes.

[CUE → KRISHIV] Krishiv, please start Backend A again."

[KRISHIV: Runs `python3 backend_a/server.py` in his terminal]
[WAIT 3 seconds]

[ACTION: Type:]
```
for i in {1..6}; do
  echo -n "Request $i: "
  curl -s https://app.team1.test:8443/api/status
  echo
done
```
[EXPECTED OUTPUT — alternating A and B again:]
```
Request 1: {"backend": "B", "status": "ok"}
Request 2: {"backend": "A", "status": "ok"}
Request 3: {"backend": "B", "status": "ok"}
Request 4: {"backend": "A", "status": "ok"}
Request 5: {"backend": "B", "status": "ok"}
Request 6: {"backend": "A", "status": "ok"}
```

"Both backends are back in rotation.
nginx automatically detected that Backend A was responding again
and resumed distributing requests to it.
No configuration change. No restart. Fully automatic recovery."

### FACULTY INTERRUPTION / VIVA QUESTIONS

Q: What is the difference between passive and active health checks in nginx?
A: Passive health check — which is what we use — means nginx only detects a failed backend when it actually tries to send a request and the connection fails. nginx does not periodically probe backends. Active health check is an nginx Plus feature where nginx sends periodic health check requests to each backend regardless of traffic.

Q: If both backends fail, what does the client see?
A: The client gets a 502 Bad Gateway response from nginx. nginx is still alive and accepting connections, but it has no healthy backends to forward to. DNS and TCP to nginx still work — the failure is at the application layer upstream from nginx.

Q: What is a single point of failure in our current setup?
A: nginx on Mac 2. If Aditya's machine goes down, the entire service goes down regardless of whether the backends are healthy. DNS would still resolve app.team1.test but the TCP connection to 10.7.17.151 would fail. Phase 2 Extension E addresses this with a standby nginx and DNS-based cutover.

Q: What layer did this failure occur at?
A: Application layer — Layer 7. DNS resolved correctly. TCP from the client to nginx succeeded. TLS succeeded. The failure was nginx-to-backend — the connection from nginx to Backend A on port 3001 was refused.

Q: What are proxy_connect_timeout and proxy_read_timeout in nginx?
A: proxy_connect_timeout is how long nginx waits for a backend to accept a TCP connection before marking it failed. proxy_read_timeout is how long nginx waits for a backend to send data after the connection is established. In our config both are set to short values so failures are detected quickly.

### FAILURE / RECOVERY
If after stopping Backend A, requests still show X-Backend: A:
- nginx may have cached the upstream connection briefly. Wait a few seconds and retry.
- If Backend A is confirmed stopped (`curl -s http://10.7.16.201:3001/api/status` fails) but nginx still serves A, the proxy_connect_timeout may not have fired yet. Wait for it.
If restarting Backend A and no requests go to A after 10 seconds:
- nginx may be in a cooldown window. Reload nginx: `nginx -s reload` on Mac 2.

---

## ════════════════════════════════════════════
## STEP 9 — PHASE 2 DNS AND RESILIENCE BEHAVIOR
## ════════════════════════════════════════════

### PURPOSE
Phase 2 extensions add resilience to the system. Phase 2 is not yet fully implemented in our project.
This step describes what has been completed and what is in progress.
The team must be honest — do not claim a feature works if it has not been tested.

### PHASE 2 STATUS (HONEST ASSESSMENT)

| Extension | Status | Notes |
|---|---|---|
| A — Backup DNS | ⏳ Not yet implemented | Om needs to configure dnsmasq on a second Mac |
| B — DNS TTL demo | ⏳ Not yet implemented | Requires short TTL config in dnsmasq |
| C — Backend firewall isolation | ⏳ Not yet implemented | Requires pf rules on Mac 3 and Mac 4 |
| D — HA Failover (nginx config) | ✅ Demonstrated in Step 8 | nginx passive failover working |
| E — Standby nginx + DNS cutover | ⏳ Not yet implemented | Requires nginx on a second Mac |

### SCREEN STATE
- **Projected:** Mac 4 / Vaidehi — Terminal OR Mac 1 / Om if backup DNS is demonstrated

### SPEAKER: Vaidehi (narrates); Om acts if backup DNS is ready

### WORD-FOR-WORD DIALOGUE

"Phase 2 extends our Phase 1 system with additional resilience features.

Let me describe what Phase 2 requires and what we have completed.

Extension D — High Availability Failover — we already demonstrated in the previous step.
nginx automatically detects when a backend is unreachable and routes traffic to the healthy backend.
That is working and proven live.

For the remaining Phase 2 extensions — backup DNS, DNS TTL, backend firewall isolation,
and standby nginx — these are the next steps in our implementation.

Let me explain what each one means.

Backup DNS: right now, Om's Mac 1 is the only DNS server.
If dnsmasq stops, no client can resolve app.team1.test and the entire service breaks.
The fix is to run a second dnsmasq on another Mac with the same records,
and configure clients to list both DNS servers. If the primary fails, the backup answers.

DNS TTL: every DNS record has a Time To Live — a number of seconds that tells clients
how long to cache the answer. If we set TTL to 30 seconds, change the DNS record,
and wait 30 seconds, clients will start resolving to the new IP.
This is the mechanism behind DNS-based traffic migration in production.

Backend firewall isolation: currently, any machine on our LAN can directly reach
port 3001 on Krishiv's machine or port 3002 on mine.
In a production system, backends should only accept connections from the load balancer.
We would use macOS pf firewall rules to block direct client access to 3001 and 3002,
while allowing nginx at 10.7.17.151 through.

Standby nginx: currently Mac 2 is a single point of failure.
The standby extension puts a second nginx on another Mac,
then changes the DNS record for app.team1.test from 10.7.17.151 to the standby IP.
Clients with cached DNS still hit the old edge briefly,
then new lookups go to the standby. This demonstrates DNS-based cutover."

### FACULTY INTERRUPTION / VIVA QUESTIONS

Q: What is a TTL in DNS and why does it matter?
A: TTL — Time To Live — is a value in seconds attached to each DNS record. It tells clients and intermediate DNS resolvers how long to cache the answer. A short TTL means changes propagate quickly but DNS servers get more queries. A long TTL means fewer queries but slower propagation when records change. In production, before a planned migration, operators lower the TTL first so that when the change happens, clients pick it up quickly.

Q: What is the difference between DNS failover and TCP failover?
A: DNS failover works at the resolution layer — you change which IP a domain name points to, and after the TTL expires, new clients go to the new server. TCP failover works at the connection layer — nginx detects a failed backend and reroutes the current request without any DNS change. DNS failover changes WHERE clients connect. TCP failover (nginx) changes where requests go once they reach the edge.

Q: What is pf and what would the firewall rule look like?
A: pf is macOS's built-in packet filter firewall. A rule to block direct access to port 3001 except from nginx would look like: pass in on en0 proto tcp from 10.7.17.151 to any port 3001. Then: block in on en0 proto tcp from any to any port 3001. This allows Mac 2 through and blocks everything else.

Q: What is a single point of failure?
A: A component whose failure causes the entire system to fail, with no redundancy or failover path. In our current setup, nginx on Mac 2 is a single point of failure. If Mac 2 goes down, no requests can be served — even if both backends are healthy.

---

## ════════════════════════════════════════════
## STEP 10 — FACULTY-INJECTED FAULT DIAGNOSIS
## ════════════════════════════════════════════

### PURPOSE
The faculty will deliberately break one part of the system and ask the team to diagnose it.
The team must identify which layer is affected and fix or explain it.
Partial credit is awarded for correct methodology even if the fix is incomplete.

### DIAGNOSTIC ORDER (ALWAYS FOLLOW THIS)
DNS → TCP → TLS → Application

Do not skip layers. Do not guess. Check each one in sequence.

### SCREEN STATE
- **Projected:** Mac 4 / Vaidehi — Terminal for diagnostics
- **Other Macs:** Ready to check their own services if pointed to

### SPEAKER: Vaidehi leads. Relevant teammate assists silently when their component is being checked.

### WORD-FOR-WORD DIAGNOSTIC SCRIPT

"Our diagnostic process always follows the same order:
DNS first, then TCP, then TLS, then Application.

We never skip a layer. If DNS fails, we do not even attempt the TCP check.
We fix the DNS problem first, then proceed.

Let me run through each check now.

Step 1 — DNS check."

[ACTION: Type:]
```
dig app.team1.test +short
```
[IF THIS RETURNS 10.7.17.151:] "DNS is working. We move to Step 2."
[IF THIS RETURNS NOTHING OR WRONG IP:] "DNS is broken. We investigate Mac 1 — dnsmasq may have stopped or the record may have been changed."

```
pgrep -fl dnsmasq
```
[IF NO OUTPUT:] "dnsmasq is not running. Om, please restart dnsmasq."
[IF WRONG IP:] "The DNS record has been changed. Om, please check dnsmasq.conf."

"Step 2 — TCP connectivity check. Can we reach nginx's port at all?"

[ACTION: Type:]
```
nc -zv 10.7.17.151 8443
```
[EXPECTED OUTPUT IF WORKING:]
```
Connection to 10.7.17.151 port 8443 [tcp/*] succeeded!
```
[IF FAILS:] "TCP to port 8443 is failing. Either nginx is down on Mac 2 or there is a firewall blocking the port."
```
# Aditya checks on Mac 2:
brew services list | grep nginx
```

"Step 3 — TLS check. Can we complete a TLS handshake?"

[ACTION: Type:]
```
curl -sv https://app.team1.test:8443/health 2>&1 | grep -E "TLSv|SSL|subject|HTTP"
```
[IF TLS FAILS — certificate error:] "The certificate has been modified or replaced. Aditya, please check the nginx TLS config."
[IF TLS SUCCEEDS:] "TLS is working. Move to Step 4."

"Step 4 — Application check. Is nginx reaching the backends?"

[ACTION: Type:]
```
curl -s https://app.team1.test:8443/api/status
```
[IF 502 Bad Gateway:] "nginx is alive but both backends are down. Check Mac 3 and Mac 4."
[IF 200 from only one backend:] "One backend is down — we demonstrated this in the failure test."
[IF 200 normal:] "Everything is working — the fault may have been transient."

### LIKELY FACULTY FAULT INJECTION SCENARIOS

| Fault | Symptom | Layer | Diagnosis Command |
|---|---|---|---|
| Stop dnsmasq on Mac 1 | `dig` returns nothing | DNS | `pgrep -fl dnsmasq` on Mac 1 |
| Change DNS record to wrong IP | `dig` returns wrong IP | DNS | Check dnsmasq.conf on Mac 1 |
| Stop nginx on Mac 2 | TCP connection refused to 8443 | TCP | `brew services list` on Mac 2 |
| Change nginx port | TCP connection refused | TCP | `lsof -i :8443` on Mac 2 |
| Replace/corrupt TLS cert | SSL certificate error in curl | TLS | `nginx -t` on Mac 2 |
| Stop both backends | 502 Bad Gateway | Application | `curl http://10.7.16.201:3001/api/status` |
| Change backend port in nginx config | 502 Bad Gateway | Application | Check nginx upstream block on Mac 2 |
| Add wrong IP to nginx upstream | Some requests get 502 | Application | Check `upstream backend_nodes` in team.conf |

### FACULTY INTERRUPTION / VIVA QUESTIONS

Q: Why do you diagnose DNS before TCP?
A: Because TCP requires an IP address, which comes from DNS. If DNS is broken, TCP cannot even start. Checking TCP when DNS is broken would just confirm TCP is failing without finding the root cause. We always go from the lowest functional dependency upward.

Q: What does 502 Bad Gateway mean?
A: 502 means nginx received a request from the client, attempted to forward it to a backend, but the backend did not respond correctly — typically because it is down or not accepting connections. The error originates at the nginx-to-backend layer, which is the application layer from the client's perspective.

Q: What does 503 Service Unavailable mean?
A: 503 means the server is temporarily unable to handle the request — usually because it is overloaded or all backends are in a cooldown period after repeated failures. nginx returns 503 when the upstream is marked down and no backup is configured.

---

## ════════════════════════════════════════════
## STEP 11 — INDIVIDUAL VIVA QUESTIONS
## ════════════════════════════════════════════

*Full viva preparation for all four members is in Sections 11–14 of this document.*
*At this point in the demo, the faculty will address each person individually.*
*Each person answers only for themselves — do not answer for a teammate.*
*Every person must be able to explain the entire system, not just their assigned role.*

### HANDOFF STATEMENT (Vaidehi says at end of demo)

"That concludes our Phase 1 live demonstration.
We have shown: private DNS resolution, end-to-end HTTPS with TLS, round-robin load balancing,
Wireshark packet evidence, HTTP caching with 304 conditional responses,
backend failure and automatic recovery, and our Phase 2 progress.

We are ready for individual viva questions."


---

# SECTION 7 — TEAM CUE SHEET

> Use this table during rehearsal. Every cue phrase triggers exactly one action from one person.
> Everyone else holds position until their own cue.

| # | Vaidehi says this exact phrase | Who acts | Exact action | Screen |
|---|---|---|---|---|
| 1 | *"Aditya, please take the screen"* | Aditya | Connects Mac 2 to projector / shares screen | Switch to Mac 2 |
| 2 | *"Aditya, please apply the filter: dns"* | Aditya | Types `dns` in Wireshark filter bar, presses Enter | Mac 2 Wireshark |
| 3 | *"Aditya, please filter: tcp.port == 8443"* | Aditya | Types `tcp.port == 8443` in filter bar, presses Enter | Mac 2 Wireshark |
| 4 | *"Aditya, please filter: tls"* | Aditya | Types `tls` in filter bar, presses Enter | Mac 2 Wireshark |
| 5 | *"Aditya, last filter — tls.record.content_type == 23"* | Aditya | Types `tls.record.content_type == 23`, presses Enter | Mac 2 Wireshark |
| 6 | *"Aditya, thank you. I will take the screen back"* | Aditya | Returns projector to Mac 4 / Vaidehi | Switch to Mac 4 |
| 7 | *"Krishiv, please stop Backend A now"* | Krishiv | Presses Ctrl+C in Backend A terminal on Mac 3 | Mac 3 terminal (not projected) |
| 8 | *"Krishiv, please start Backend A again"* | Krishiv | Runs `python3 backend_a/server.py` in Mac 3 terminal | Mac 3 terminal (not projected) |
| 9 | *"Om, please take the screen"* (Phase 2 only) | Om | Connects Mac 1 to projector | Switch to Mac 1 |
| 10 | *"Om, please show the dnsmasq config"* (Phase 2 only) | Om | `cat ~/Documents/CN_Project/config/dnsmasq.conf` | Mac 1 terminal |

**Rules for the cue sheet:**
- Nobody speaks except Vaidehi. Aditya, Om, and Krishiv are silent throughout.
- Nobody acts without hearing their exact cue phrase.
- If Vaidehi pauses or makes a mistake, teammates do not jump in — they wait for the cue.
- Aditya must NOT change Wireshark filters unless Vaidehi says the exact filter phrase.

---

# SECTION 8 — PROTOCOL EXPLANATION CHEAT SHEET

## DNS
- **What:** Converts a domain name to an IP address
- **Protocol:** UDP (primarily), TCP for large responses
- **Port:** 53
- **Our setup:** dnsmasq on Om's Mac 1 at 10.7.15.236
- **Record type:** A record — `address=/app.team1.test/10.7.17.151`
- **When it runs:** Before any TCP connection. Once. Then TCP takes over.
- **What it does NOT do:** DNS does not make connections. It does not proxy traffic. It only answers name→IP lookups.

## TCP
- **What:** Reliable, ordered, connection-oriented transport protocol
- **Three-way handshake:** SYN → SYN-ACK → ACK
- **Port used:** 8443 (nginx HTTPS), 3001 (Backend A), 3002 (Backend B), ephemeral (client source)
- **What "ephemeral" means:** The client OS picks a random high port (49152–65535) as the source port for each outgoing connection. It is temporary — released when the connection closes.
- **What TCP guarantees:** Packets arrive in order, retransmitted if lost, no duplicates

## TLS
- **What:** Encryption layer on top of TCP. Makes HTTP into HTTPS.
- **Handshake steps:**
  1. ClientHello — client advertises TLS versions, cipher suites, sends SNI
  2. ServerHello — server selects TLS version and cipher
  3. Certificate — server sends its X.509 certificate
  4. Key Exchange — both sides derive a shared session key (never sent over the wire)
  5. Finished — both confirm handshake; encrypted channel open
- **In our setup:** TLS terminates at nginx on Mac 2. Backends receive plain HTTP.
- **Version used:** TLS 1.3
- **Cipher:** TLS_AES_256_GCM_SHA384
- **Certificate:** Self-signed, issued for app.team1.test, CN=app.team1.test, installed in Mac 4 Keychain

## HTTP / HTTPS
- **What:** Application-layer request/response protocol
- **HTTPS = HTTP inside TLS**
- **Key headers in our project:**
  - `X-Backend: A` or `B` — identifies which backend served the request
  - `Cache-Control: max-age=60` — client can cache for 60 seconds
  - `ETag: "72db076608216f33"` (Backend A) / `"backend-b-v1"` (Backend B) — cache fingerprint
  - `If-None-Match: "<etag>"` — conditional request header sent by client
  - `304 Not Modified` — server confirms cache is still fresh, no body
  - `Server: nginx/1.31.6` — identifies the edge server
  - `X-Forwarded-For` — nginx adds the real client IP when proxying

## nginx
- **What it does simultaneously:**
  - Terminates TLS (decrypts HTTPS)
  - Acts as reverse proxy (forwards HTTP to backends)
  - Load-balances using round-robin
  - Rewrites HTTP → HTTPS (port 8080 redirects to 8443)
- **Config file location:** `/opt/homebrew/etc/nginx/servers/team.conf`
- **Upstream block:** `server 10.7.16.201:3001;` and `server 10.7.2.96:3002;`
- **Health check:** Passive — marks backend failed after connection refused, restores automatically

## Load Balancing
- **Algorithm:** Round-robin (default in nginx)
- **How it works:** Requests 1, 3, 5... → Backend A. Requests 2, 4, 6... → Backend B.
- **What the client sees:** Always the same domain, always the same IP. Different X-Backend header.
- **Why it matters:** Distributes load, provides redundancy

## HTTP Caching
- **Cache-Control: max-age=60** → valid for 60 seconds from receipt
- **ETag** → fingerprint of response body (MD5 hash on Backend A)
- **If-None-Match** → client sends back ETag when revalidating
- **304 Not Modified** → nothing changed, keep your cached copy, no body sent
- **Cache-Control: no-store** → on error responses — errors must never be cached

---

# SECTION 9 — FAILURE DIAGNOSIS PROCEDURE

## The Rule: Always DNS → TCP → TLS → Application

Never skip a layer. Never guess. Run the check, read the result, move to the next layer only if the current one passes.

---

### CHECK 1 — DNS LAYER

**Command:**
```bash
dig app.team1.test +short
```

| Result | Meaning | Next Step |
|---|---|---|
| `10.7.17.151` | DNS working correctly | Proceed to Check 2 |
| Empty / no output | dnsmasq not running or client not using Mac 1 DNS | Fix DNS first |
| Wrong IP (not 10.7.17.151) | DNS record changed or corrupted | Fix dnsmasq.conf on Mac 1 |
| `SERVFAIL` | dnsmasq is running but has a config error | Check dnsmasq.conf syntax |

**If DNS fails — checks to run:**
```bash
# On Mac 1 — is dnsmasq running?
pgrep -fl dnsmasq

# On Mac 4 — is DNS configured to use Mac 1?
networksetup -getdnsservers Wi-Fi
# Must show: 10.7.15.236

# Force query directly to Mac 1 to isolate client vs server:
dig app.team1.test @10.7.15.236 +short
# If this works but dig without @ fails → client DNS setting is wrong
# If this also fails → dnsmasq is the problem
```

---

### CHECK 2 — TCP LAYER

**Command:**
```bash
nc -zv 10.7.17.151 8443
```

| Result | Meaning | Next Step |
|---|---|---|
| `succeeded!` | TCP to nginx working | Proceed to Check 3 |
| `Connection refused` | nginx is not running on Mac 2 | Restart nginx |
| `Operation timed out` | Mac 2 unreachable or firewall blocking | Check ping, check firewall |

**If TCP fails — checks to run:**
```bash
# On Mac 2 — is nginx running?
brew services list | grep nginx

# On Mac 2 — restart nginx if needed:
brew services restart nginx

# On Mac 4 — can we ping Mac 2 at all?
ping -c 3 10.7.17.151
# If ping fails → LAN connectivity issue, not nginx
```

---

### CHECK 3 — TLS LAYER

**Command:**
```bash
curl -sv https://app.team1.test:8443/health 2>&1 | grep -E "TLSv|SSL|subject|error|HTTP"
```

| Result | Meaning | Next Step |
|---|---|---|
| `TLSv1.3` + `HTTP/1.1 200` | TLS working | Proceed to Check 4 |
| `SSL certificate problem` | Cert invalid or not trusted on client | Check cert installation |
| `SSL: no alternative certificate subject` | Wrong cert / CN mismatch | Check nginx cert config on Mac 2 |
| `Connection refused` | nginx is not listening | Go back to TCP check |

**If TLS fails — checks to run:**
```bash
# On Mac 2 — test nginx config syntax:
nginx -t

# On Mac 2 — check cert files exist:
ls -la /Users/aditya.2024/Documents/Projects/CN_Project/configs/tls/

# On Mac 4 — re-trust the cert if needed:
sudo security add-trusted-cert -d -r trustRoot \
  -k /Library/Keychains/System.keychain \
  /path/to/team1.test.crt
```

---

### CHECK 4 — APPLICATION LAYER

**Command:**
```bash
curl -s https://app.team1.test:8443/api/status
```

| Result | Meaning | Next Step |
|---|---|---|
| `{"backend":"A"...}` or `{"backend":"B"...}` | Fully working | All good |
| `502 Bad Gateway` | nginx alive, both backends down | Check Mac 3 and Mac 4 |
| `{"backend":"B"...}` only, never A | Backend A down | Check Mac 3 |
| `{"backend":"A"...}` only, never B | Backend B down | Check Mac 4 |

**If Application fails — checks to run:**
```bash
# Test Backend A directly (from any Mac on LAN):
curl -s http://10.7.16.201:3001/api/status

# Test Backend B directly:
curl -s http://10.7.2.96:3002/api/status

# On Mac 3 — restart Backend A:
python3 backend_a/server.py

# On Mac 4 — restart Backend B:
python3 backend_b/server.py

# On Mac 2 — check nginx error log for upstream errors:
tail -20 /opt/homebrew/var/log/nginx/team_error.log
```

---

# SECTION 10 — PHASE 2 EXPLANATION

## What Phase 2 Is

Phase 2 extends the working Phase 1 system with resilience, isolation, and controlled failure recovery.
It does not replace Phase 1 — it builds on top of it.

## Extension A — Backup DNS Resolver (Om's task)

**What it adds:** A second dnsmasq instance on a different Mac (e.g., Mac 4) with the same records.
**How clients use it:** Configure both DNS servers in System Settings → Network → DNS.
**What it proves:** If Om's Mac 1 stops, clients automatically fall back to the second DNS server and name resolution continues.
**How to demonstrate:** Stop dnsmasq on Mac 1. Run `dig app.team1.test` from a client. It still resolves.

## Extension B — DNS TTL and Controlled Record Change (Om's task)

**What it adds:** Set a short TTL (e.g. 30 seconds) in dnsmasq.
**In dnsmasq.conf:** `address=/app.team1.test/10.7.17.151` with `--local-ttl=30`
**How to demonstrate:**
1. Resolve the name — client caches the answer for 30 seconds
2. Change the record to a different IP
3. Within 30 seconds: `dig` still returns the old IP (cached)
4. After 30 seconds: `dig` returns the new IP
5. Flush DNS cache manually: `sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder`
**What it proves:** TTL controls how long clients hold stale DNS answers. Lower TTL = faster migration.

## Extension C — Backend Firewall Isolation (Krishiv + Vaidehi's task)

**What it adds:** pf firewall rules on Mac 3 and Mac 4 that block direct access to ports 3001/3002 from anyone except Mac 2 (nginx).
**What it proves:** Backends are not directly accessible to clients. They can only be reached through the load balancer.
**How to demonstrate:**
- From Mac 4: `curl http://10.7.16.201:3001/api/status` → blocked/timed out
- From Mac 2: same command → succeeds (nginx can still reach it)

## Extension D — HA Failover (✅ ALREADY DEMONSTRATED in Step 8)

**What it adds:** nginx passive health checks — already built into our nginx config via `proxy_connect_timeout`.
**What it proves:** Service continues through the healthy backend when one fails. Demonstrated live in Step 8.

## Extension E — Standby nginx + DNS Cutover (Aditya + Om's task)

**What it adds:** A second nginx instance on another Mac with the same config and certificate.
**How to demonstrate:**
1. Configure nginx on standby Mac (e.g., Mac 3 temporarily), test it works directly
2. Change DNS: `app.team1.test → <standby IP>` in dnsmasq.conf, restart dnsmasq
3. Flush DNS cache on client
4. `dig app.team1.test` now returns standby IP
5. `curl https://app.team1.test:8443/api/status` now hits standby nginx
6. Old cached clients briefly still hit original Mac 2 (TTL effect)
**What it proves:** Edge migration using DNS cutover. The application moves without changing any client configuration.

---

---

# SECTION 11 — FULL VIVA PREPARATION: OM (Mac 1 — DNS)

> Om's primary role is DNS but he must answer questions about the entire system.
> Every answer below is written to be spoken aloud in 30–60 seconds.

---

## Phase 1 Viva Questions — Om

**Q1: What is DNS and what does it do in your project?**
A: DNS stands for Domain Name System. It is a directory service that converts a human-readable name — like app.team1.test — into an IP address. In our project, when a client wants to reach the service, it first asks my Mac what IP app.team1.test points to. My dnsmasq server replies with 10.7.17.151, which is Aditya's nginx machine. DNS is done after that — it plays no role in the actual connection.

**Q2: What is dnsmasq and why did you use it?**
A: dnsmasq is a lightweight DNS forwarder and DHCP server. We used it because it is easy to configure on macOS, supports custom A records for private domains, and runs with a simple config file. You define your records with the `address=` directive. It is the standard tool for this kind of local DNS setup.

**Q3: What does your dnsmasq.conf contain?**
A: It has four key lines. `port=53` sets it to listen on the standard DNS port. `listen-address=127.0.0.1,10.7.15.236` makes it bind to the loopback and my LAN interface. `bind-interfaces` stops it from accidentally listening on other interfaces. And `address=/app.team1.test/10.7.17.151` is the A record that maps our domain to Aditya's nginx machine.

**Q4: What is an A record?**
A: An A record is a DNS record type that maps a domain name to an IPv4 address. In our dnsmasq config, `address=/app.team1.test/10.7.17.151` is our A record. When a client queries for app.team1.test, dnsmasq returns 10.7.17.151 as the answer.

**Q5: What port does DNS use and which transport protocol?**
A: DNS uses port 53. It primarily uses UDP because DNS messages are small and UDP is fast. For larger responses that exceed 512 bytes, DNS falls back to TCP on port 53. In our project, dnsmasq handles both. Zone transfers between DNS servers also use TCP.

**Q6: Why did you use .test and not .local or .com?**
A: .local is reserved by macOS for Bonjour mDNS — Apple's zero-configuration networking service. If you use .local as a DNS domain, it conflicts with mDNS and causes unpredictable resolution failures. .com is a real public domain we do not own. .test is an IANA-reserved namespace specifically for testing and development. It is guaranteed never to be delegated on the public internet.

**Q7: What is the difference between DNS resolution and making an HTTP connection?**
A: DNS resolution is a lookup — the client asks my server for an IP and gets an answer. It uses UDP and takes one round trip. Making an HTTP connection is a separate process — it involves a TCP three-way handshake followed by a TLS handshake followed by the HTTP request. DNS ends the moment the IP is returned. The actual connection uses that IP but has nothing more to do with DNS.

**Q8: What would happen if your dnsmasq was not running during the demo?**
A: The dig command from any client would return nothing or time out. The curl command to https://app.team1.test would fail with "Could not resolve host" — not because the server is down, but because the client cannot find the IP. DNS failure prevents any higher-layer service from starting. The fix is to restart dnsmasq on my machine.

**Q9: What is a subnet and what is ours?**
A: A subnet is a logically defined segment of a network where all machines share the same network prefix and can communicate directly without a router. Our subnet is 10.7.0.0/19. The /19 means the first 19 bits of the address are the network portion. This gives us addresses from 10.7.0.1 to 10.7.31.254 — about 8190 usable hosts. All four of our machines are within this range, so they communicate directly.

**Q10: What is a gateway and when would your machine use it?**
A: A gateway is a router that sits at the edge of a subnet and forwards traffic to other networks or the internet. Our gateway is 10.7.0.1. Our four machines use it only if they need to reach something outside the 10.7.0.0/19 range. During our demo, all traffic stays within the subnet — client to DNS to nginx to backends — so the gateway is never actually used.

**Q11: How does a client know which DNS server to use?**
A: The DNS server is configured in the operating system's network settings. On macOS you set it in System Settings → Wi-Fi → Details → DNS. Vaidehi's machine has 10.7.15.236 — my IP — set as the DNS server. Every DNS query from her machine goes to my dnsmasq first. I could also set it via the command line: `networksetup -setdnsservers Wi-Fi 10.7.15.236`.

**Q12: What is the difference between iterative and recursive DNS resolution?**
A: In recursive resolution, the client asks one DNS server which goes and finds the answer on its behalf — querying root servers, TLD servers, and authoritative servers as needed — and returns the final answer. In iterative resolution, the server just returns a referral — "ask this other server." Our dnsmasq acts as a recursive resolver for clients. For app.team1.test it answers directly from its own config — no external lookups needed.

**Q13: What is DNS caching and TTL?**
A: When a DNS resolver returns an answer, it includes a TTL — Time To Live — in seconds. The client caches the answer for that many seconds. If the same domain is queried again within that window, the client uses the cached answer without contacting the DNS server. After the TTL expires, the client must query again. A short TTL like 30 seconds means changes propagate quickly. A long TTL like 3600 seconds means less DNS traffic but slower propagation.

**Q14: What is nslookup and how is it different from dig?**
A: Both are DNS query tools. nslookup is older, simpler, and available on most systems. dig gives more detailed output — it shows the full DNS response including TTL, response flags, query time, and the server that answered. For debugging, dig is preferred. For a quick check, nslookup works fine. Both would confirm that app.team1.test resolves to 10.7.17.151 via my dnsmasq.

**Q15: What is the relationship between DNS and nginx in your project? Is nginx a DNS server?**
A: No, nginx is not a DNS server. They are completely separate components at different layers. DNS runs at the application layer on UDP port 53 and only answers name-to-IP questions. nginx runs at the application layer on TCP port 8443 and handles HTTP/HTTPS proxying. DNS tells the client WHERE to connect. nginx decides what to do with the request AFTER the client connects. They never communicate with each other directly.

---

## Phase 2 / Full System Viva Questions — Om

**Q16: What is backup DNS and why is it needed?**
A: Right now, my Mac 1 is the only DNS server. If my machine goes down, no client can resolve app.team1.test and the entire service appears offline — even if nginx and both backends are perfectly healthy. A backup DNS server is a second machine running dnsmasq with the same records. Clients list both DNS servers. If primary fails, the OS automatically tries the backup. This removes DNS as a single point of failure.

**Q17: How would you configure backup DNS on macOS?**
A: I would install dnsmasq on another Mac — say Mac 4 — with the same dnsmasq.conf records pointing app.team1.test to 10.7.17.151. Then on all client Macs I would add both IPs in System Settings → DNS: primary 10.7.15.236, secondary 10.7.2.96. If primary doesn't respond within a timeout, the OS automatically queries the secondary.

**Q18: What is DNS TTL and how would you demonstrate it?**
A: I add `--local-ttl=30` to dnsmasq to set a 30-second TTL. First I resolve app.team1.test — the client caches the answer. Then I change the record to point to a different IP and restart dnsmasq. Within 30 seconds the client still gets the old answer from cache. After 30 seconds, or after manually flushing with `sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder`, the new IP appears.

**Q19: What is DNS cache flushing and when would you need it?**
A: DNS cache flushing clears the operating system's cached DNS answers, forcing the next query to go to the DNS server. On macOS the command is `sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder`. You need it when you have changed a DNS record and want clients to pick up the new answer immediately without waiting for the TTL to expire — for example during a planned migration or after fixing a wrong record.

**Q20: What is the difference between a DNS failure and a backend failure from a user's perspective?**
A: A DNS failure means the browser shows "Server not found" or "Could not resolve host" — the user cannot even begin a connection. A backend failure means the domain resolves, the HTTPS connection to nginx succeeds, but nginx returns 502 Bad Gateway — the user sees an error page. The difference is at which layer the failure occurs: DNS failure stops the request before TCP; backend failure stops it after TLS.

**Q21: What would happen if you pointed app.team1.test to the wrong IP in dnsmasq?**
A: DNS would resolve successfully — it would return the wrong IP — but the TCP connection would either time out if nothing is at that IP or be refused if something is there on a different port. The client would see a connection error, not a DNS error. This is different from DNS being down: here the lookup succeeds but returns wrong information. The diagnostic would show dig returns an answer but TCP fails.

**Q22: What is an AAAA record?**
A: An AAAA record maps a domain name to an IPv6 address — the same concept as an A record but for IPv6. In our project we only use IPv4 and A records. If we wanted to support IPv6 clients, we would add AAAA records pointing app.team1.test to the IPv6 address of Mac 2.

**Q23: What is the OSI model and where does DNS sit?**
A: The OSI model has 7 layers: Physical, Data Link, Network, Transport, Session, Presentation, Application. DNS is an Application layer protocol — Layer 7. It runs on top of UDP (Transport Layer 4) and IP (Network Layer 3). Even though DNS is application-layer, it is used to resolve names before TCP connections are made, so it sits logically before the rest of the application stack in a request.

**Q24: What is the difference between a DNS server and a DNS resolver?**
A: A DNS resolver is the client-side component — it initiates queries on behalf of applications. On macOS, the OS resolver sends queries to the configured DNS server. A DNS server responds to those queries. In our project, my dnsmasq is both — it acts as a server for client queries and as a recursive resolver for any domains it does not have records for, forwarding those upstream. For our private records, it answers directly.

**Q25: Why does every request start with DNS even if the client has visited the same domain before?**
A: It does not — DNS caching prevents repeated lookups. After the first successful resolution, the client caches the answer for the duration of the TTL. Subsequent requests within that TTL window use the cached IP directly without querying DNS again. This is why TTL management matters — too long a TTL and clients hold stale records; too short and every request hits the DNS server.

---

# SECTION 12 — FULL VIVA PREPARATION: ADITYA (Mac 2 — nginx)

---

## Phase 1 Viva Questions — Aditya

**Q1: What is nginx and what is it doing in your project?**
A: nginx is a high-performance web server and reverse proxy. In our project it is doing three things simultaneously: terminating TLS so all HTTPS traffic is decrypted at the edge, acting as a reverse proxy that forwards HTTP requests to the backends, and load-balancing across Backend A and Backend B using round-robin. It is the single public entry point — no client ever talks directly to a backend.

**Q2: What is a reverse proxy and how is it different from a forward proxy?**
A: A reverse proxy sits in front of servers and acts on their behalf. Clients connect to the reverse proxy thinking it is the server. The proxy forwards the request to the appropriate backend and returns the response. A forward proxy sits in front of clients — it intercepts outgoing traffic on behalf of clients, like a corporate proxy or VPN. In our project nginx is a reverse proxy.

**Q3: What is TLS termination?**
A: TLS termination means nginx decrypts the incoming HTTPS connection from the client and communicates with the backends over plain HTTP. The TLS layer ends at nginx. From nginx to Backend A or B, the traffic is unencrypted HTTP on the private LAN. Centralising TLS at the edge means backends do not need certificates or TLS configuration — they stay simple.

**Q4: What is your nginx upstream block and what does it do?**
A: The upstream block defines the backend pool. In our config: `upstream backend_nodes { server 10.7.16.201:3001; server 10.7.2.96:3002; }`. This tells nginx about the two backends. By default nginx uses round-robin across all servers in the upstream. When a request arrives, nginx picks the next server in the list and forwards it there.

**Q5: What is round-robin load balancing?**
A: Round-robin distributes requests sequentially across all backends in order. Request 1 → Backend A, request 2 → Backend B, request 3 → Backend A, and so on. It assumes equal capacity across backends. It is the default algorithm in nginx and works well when requests are uniform in cost and backends have equal performance.

**Q6: What is the TLS handshake? Walk through each step.**
A: The TLS handshake has five steps. First, ClientHello — the client advertises supported TLS versions, cipher suites, and includes SNI. Second, ServerHello — nginx picks TLS 1.3 and a cipher suite, then sends the certificate. Third, Certificate — the client validates the certificate against its trust store. Fourth, Key Exchange — both sides derive a shared session key using ECDHE; the key never crosses the network. Fifth, Finished — both sides confirm the handshake. After this, all application data is encrypted.

**Q7: What is SNI?**
A: SNI stands for Server Name Indication. It is a TLS extension where the client includes the hostname it wants — in our case app.team1.test — inside the ClientHello message, before TLS is fully established. This lets nginx know which certificate to present, because a single nginx instance could serve multiple domains. Without SNI, nginx would not know which cert to use before the TLS session is negotiated.

**Q8: What certificate do you use and how was it created?**
A: We use a self-signed certificate generated with OpenSSL. The certificate has CN=app.team1.test and SANs including DNS:app.team1.test and IP:10.7.17.151. It uses RSA 2048-bit with SHA-256 and is valid for one year. Because it is self-signed, we installed it manually into the macOS Keychain on each client Mac so that curl and browsers trust it without the -k bypass.

**Q9: What is the difference between HTTP port 8080 and HTTPS port 8443 in your config?**
A: Port 8080 is our HTTP listener. It serves one purpose: redirect any plain HTTP request to HTTPS with a 301 redirect to port 8443. Port 8443 is our HTTPS listener — it terminates TLS and proxies requests to backends. We use 8080/8443 instead of 80/443 because Homebrew nginx runs without root privileges and macOS requires root to bind below port 1024.

**Q10: What headers does nginx add when proxying?**
A: nginx adds X-Real-IP with the client's actual IP, X-Forwarded-For with the proxy chain, and X-Forwarded-Proto set to https. These tell the backend where the real client came from, since the backend only sees nginx's IP as the connection source. nginx also passes through X-Backend from the backend to the client using proxy_pass_header.

**Q11: What does proxy_connect_timeout do?**
A: proxy_connect_timeout is how long nginx waits for a backend to accept a TCP connection before giving up and marking it failed. We set it to 5 seconds. If nginx tries to connect to Backend A and gets no response within 5 seconds, it considers Backend A unreachable and tries Backend B instead. This is the passive health check mechanism.

**Q12: What is a 502 Bad Gateway error?**
A: 502 means nginx received the client's request successfully, attempted to forward it to a backend, but the backend was unreachable or returned an invalid response. nginx itself is fine — the error is between nginx and the upstream. If both backends are down simultaneously, every request gets a 502. If only one backend is down, nginx routes to the other and no 502 is seen by the client.

**Q13: What is proxy_pass and what does it do?**
A: proxy_pass is the nginx directive that forwards an incoming request to a backend. In our config, `proxy_pass http://backend_nodes;` tells nginx to forward the request to whichever server the round-robin algorithm selects from the backend_nodes upstream pool. nginx makes a new HTTP connection to that backend, forwards the request, receives the response, and sends it back to the client.

**Q14: What is the nginx.conf structure? How is your config organized?**
A: The main nginx.conf at /opt/homebrew/etc/nginx/nginx.conf includes all files from the servers/ directory. Our team config is at /opt/homebrew/etc/nginx/servers/team.conf. That file contains the upstream block and two server blocks — one for port 8080 (HTTP redirect) and one for port 8443 (HTTPS proxy). Separating configs into the servers/ directory keeps things clean and allows nginx to be reloaded with `nginx -s reload` without restarting.

**Q15: What command do you use to reload nginx without dropping connections?**
A: `nginx -s reload`. This sends a SIGHUP signal to the nginx master process. The master process reads the new config, starts new worker processes with the new config, and gracefully shuts down old workers after they finish handling current requests. In-flight connections are not dropped. Before reloading, always run `nginx -t` to verify the config syntax.

---

## Phase 2 / Full System Viva Questions — Aditya

**Q16: What is a single point of failure in your current setup?**
A: nginx on my Mac 2. If my machine goes down, DNS resolves correctly, backends are healthy, but TCP connections to 10.7.17.151:8443 fail. The entire service becomes unreachable. Phase 2 Extension E addresses this with a standby nginx on another Mac and a DNS record change to point app.team1.test at the standby IP.

**Q17: How would you implement backend failover with max_fails in nginx?**
A: In the upstream block you can add `max_fails=3 fail_timeout=30s` to each server directive. After 3 consecutive failed connection attempts within 30 seconds, nginx marks that backend as unavailable for 30 seconds. After 30 seconds, nginx tries it again. Our current setup uses nginx's default passive behavior which achieves a similar effect.

**Q18: What is the difference between active and passive health checks?**
A: Passive health checks — what we use — only detect failures when an actual client request fails to reach the backend. nginx notices the failed connection and stops routing to that backend. Active health checks — an nginx Plus feature — send dedicated periodic probe requests to each backend regardless of traffic, so failures are detected faster. In production you want active health checks for faster failover.

**Q19: What is a standby nginx and how does DNS-based cutover work?**
A: A standby nginx is a second machine running nginx with the same configuration and certificate. DNS-based cutover means changing the DNS A record for app.team1.test from 10.7.17.151 to the standby IP. After the DNS TTL expires, new DNS lookups resolve to the standby. Clients with cached DNS still reach the old edge until their TTL expires. This demonstrates graceful traffic migration without changing any client configuration.

**Q20: What is keep-alive and does nginx use it?**
A: HTTP keep-alive allows multiple requests to reuse the same TCP connection instead of opening a new one for each request. This reduces latency from repeated TCP handshakes. nginx supports keep-alive with clients by default and can also use keep-alive to backends with the keepalive directive in the upstream block. In our demo, short curl commands open new connections each time, so keep-alive is not visible.

**Q21: What would happen to in-flight requests if you reloaded nginx during the demo?**
A: `nginx -s reload` is graceful — existing connections finish normally. New connections use the new config. So in-flight requests complete with the old config and new requests get the new config. This is why reload is safe to use during a live demo if a config change is needed.

**Q22: How does nginx know to use round-robin vs least_conn?**
A: Round-robin is the default — you do not need to specify it. To use least_conn, you add the `least_conn;` directive inside the upstream block. Our config uses the default round-robin. If requests had significantly different processing times, least_conn would distribute load more evenly.

**Q23: What is a 301 redirect and why does your HTTP listener use it?**
A: A 301 Moved Permanently tells the client that the resource has moved to a new URL permanently. Our port 8080 server block returns a 301 redirecting to the HTTPS equivalent on port 8443. The client then makes a new request to the HTTPS URL. The 301 is cached by the browser — future requests go directly to HTTPS without hitting 8080 first.

**Q24: What does the X-Forwarded-Proto header tell the backend?**
A: It tells the backend whether the original client request was HTTP or HTTPS. Since nginx terminates TLS, the backend only sees plain HTTP from nginx. Without X-Forwarded-Proto, the backend would incorrectly think the client was using plain HTTP. With it, the backend knows the client actually used HTTPS even though the nginx-to-backend leg is plain HTTP.

**Q25: What is the cloud equivalent of your nginx setup?**
A: In AWS, our nginx is equivalent to an Application Load Balancer — it terminates TLS, load-balances across EC2 instances, and acts as the single public entry point. The backends would be EC2 instances in a target group. In GCP it would be a Cloud Load Balancer with a backend service. The concepts are identical — edge TLS termination, health checks, round-robin or least-connection routing.

---

# SECTION 13 — FULL VIVA PREPARATION: KRISHIV (Mac 3 — Backend A)

---

## Phase 1 Viva Questions — Krishiv

**Q1: What does your backend do?**
A: Backend A is a lightweight HTTP REST server written in Python using the built-in http.server library. It listens on 0.0.0.0:3001 — binding to all interfaces so it is reachable from the LAN, not just locally. It serves two endpoints: GET / which returns a plain text confirmation, and GET /api/status which returns JSON: {"backend": "A", "status": "ok"}. It also sets X-Backend: A on every response so we can identify which backend served a request.

**Q2: Why did you bind to 0.0.0.0 instead of 127.0.0.1?**
A: 127.0.0.1 is the loopback address — it only accepts connections from the same machine. If I bound to 127.0.0.1, nginx on Mac 2 could not reach my backend. 0.0.0.0 means listen on all available network interfaces — including the LAN interface en0 at 10.7.16.201. This makes the backend reachable from any machine on the LAN.

**Q3: What is HTTP and how does it work?**
A: HTTP — HyperText Transfer Protocol — is a request-response protocol. The client sends a request with a method, a URL, headers, and optionally a body. The server sends a response with a status code, headers, and a body. In our project, nginx sends HTTP requests to my backend on port 3001, and my backend returns HTTP responses. All of this is plain text — unencrypted — because TLS terminates at nginx.

**Q4: What is a REST API?**
A: REST stands for Representational State Transfer. A REST API uses standard HTTP methods — GET, POST, PUT, DELETE — to expose resources at URLs. Our backend is a minimal REST API. GET /api/status is a resource that returns the backend's health status as JSON. REST APIs are stateless — each request is independent and contains all the information needed to process it.

**Q5: What is JSON and why does your backend return it?**
A: JSON — JavaScript Object Notation — is a lightweight text format for structured data. It uses key-value pairs: {"backend": "A", "status": "ok"}. We use JSON because it is the standard format for REST APIs, it is human-readable, and it is easy to parse in any language. The Content-Type header in our response is application/json to tell the client what format it is receiving.

**Q6: What is the X-Backend header and why does it matter?**
A: X-Backend is a custom HTTP response header that identifies which backend server handled the request. The X- prefix means it is a non-standard, application-defined header. We set it to "A" on every response from Backend A and "B" on every response from Backend B. This lets us prove load balancing is working — if we see X-Backend alternating between A and B across multiple requests, nginx is correctly distributing traffic.

**Q7: What is Cache-Control: max-age=60?**
A: Cache-Control is an HTTP header that controls caching behaviour. max-age=60 tells the client that this response is valid for 60 seconds after it was received. Within that window, the client can serve the response from its local cache without making any network request. After 60 seconds, the cache is stale and the client must revalidate or refetch.

**Q8: What is an ETag and how does your backend compute it?**
A: ETag stands for Entity Tag. It is a fingerprint that represents a specific version of a resource. Our Backend A computes the ETag as the first 16 hexadecimal characters of the MD5 hash of the response body. Since the body is always {"backend": "A", "status": "ok"}, the ETag is always "72db076608216f33". If the body ever changed, the ETag would automatically change too — no manual update needed.

**Q9: What is a 304 Not Modified response?**
A: 304 is an HTTP status code meaning the resource has not changed since the version identified by the client's ETag. When a client sends If-None-Match: "72db076608216f33" and the server confirms the ETag still matches, it returns 304 with no body. The client continues using its cached copy. This saves bandwidth — the full JSON payload is not retransmitted.

**Q10: What is the difference between Cache-Control: max-age and Cache-Control: no-store?**
A: max-age=60 says cache this response and consider it fresh for 60 seconds. no-store says never cache this response at all — not in the browser, not in any proxy. Backend A uses no-store on error responses like 404. This prevents a transient error page from being cached and served to future requests that would otherwise succeed.

**Q11: What does HEAD request mean and why did you implement it?**
A: An HTTP HEAD request is identical to GET but the server returns only the headers — no body. It is useful for checking if a resource exists or getting metadata without downloading content. RFC 7231 requires that any server implementing GET also support HEAD. We added `do_HEAD` to our server so health check tools and proxies that use HEAD do not get a 501 Not Implemented error.

**Q12: What is a port and what is port 3001?**
A: A port is a 16-bit number from 0 to 65535 that identifies a specific service or application on a machine. IP addresses identify machines; ports identify services on those machines. Port 3001 is an unprivileged port — above 1024 — that we assigned to Backend A. When nginx connects to 10.7.16.201:3001, it is saying: connect to Krishiv's Mac and talk to the service registered on port 3001.

**Q13: What is the difference between TCP and UDP?**
A: TCP — Transmission Control Protocol — is connection-oriented. It establishes a connection with a three-way handshake, guarantees that packets arrive in order, retransmits lost packets, and provides flow control. HTTP uses TCP. UDP — User Datagram Protocol — is connectionless. It sends packets without establishing a connection, does not guarantee delivery or order, and has lower overhead. DNS uses UDP.

**Q14: What happens if nginx cannot reach your backend?**
A: nginx tries to connect to 10.7.16.201:3001. If the connection is refused or times out — because my server is not running — nginx marks Backend A as temporarily unavailable after the proxy_connect_timeout fires. Subsequent requests go to Backend B only. nginx periodically retries Backend A and re-adds it to the pool when it responds. The client never sees a 502 as long as Backend B is healthy.

**Q15: Why does the client never directly contact your backend?**
A: Because the client only knows about app.team1.test which resolves to Aditya's nginx at 10.7.17.151. My backend IP 10.7.16.201 is only in nginx's upstream config — it is never exposed to clients. This is the reverse proxy pattern. It means my backend can change its IP or port without any client reconfiguration — only nginx needs to be updated.

---

## Phase 2 / Full System Viva Questions — Krishiv

**Q16: What is backend firewall isolation and why would you implement it?**
A: Currently any machine on our LAN can directly reach port 3001 on my Mac. Isolation means adding pf firewall rules that block direct access to port 3001 from all sources except nginx at 10.7.17.151. This enforces that backends are only reachable through the load balancer — clients cannot bypass nginx and talk to backends directly. It improves security and ensures all traffic flows through the intended path.

**Q17: What is pf and how would you write a rule for port 3001?**
A: pf is macOS's built-in packet filter firewall. A rule to allow only nginx and block everyone else on port 3001 would be: first `pass in on en0 proto tcp from 10.7.17.151 to any port 3001 keep state` to allow nginx, then `block in on en0 proto tcp from any to any port 3001` to block everything else. Rules are evaluated in order — the first matching rule wins.

**Q18: What is the difference between a firewall and a router?**
A: A router forwards packets between networks based on IP addresses. A firewall filters packets based on rules — it can allow or block based on source IP, destination IP, port, protocol, and connection state. A firewall can run on the same machine as the service it protects. Our pf firewall would run on Mac 3, filtering connections before they reach the Python server.

**Q19: What would happen to the demo if Backend A and Backend B both went down?**
A: nginx would return 502 Bad Gateway to every client request. DNS would still work — app.team1.test still resolves to 10.7.17.151. The TCP connection from client to nginx would still succeed. TLS would still succeed. But nginx would have no healthy backends to forward to, so it would return 502. The failure is at the application layer — nginx to upstream.

**Q20: What is HTTP/1.1 keep-alive?**
A: HTTP/1.1 introduced persistent connections by default. After one request-response cycle, the TCP connection stays open for potential reuse. The client can send another request without a new TCP handshake. This reduces latency and overhead. Our backend uses Python's BaseHTTPRequestHandler which supports this. The Connection: keep-alive header signals both sides to maintain the connection.

**Q21: What is the OSI layer your backend operates at?**
A: Backend A operates at Layer 7 — the Application layer — because it speaks HTTP, a Layer 7 protocol. It also implicitly uses Layer 4 (TCP) for the transport, Layer 3 (IP) for addressing, and Layer 2 (Ethernet/Wi-Fi) for the physical link. But from our backend's perspective, we only implement HTTP logic. The OS handles the lower layers transparently.

**Q22: What is stateless in the context of REST?**
A: Stateless means each HTTP request is fully independent. The server does not store any session information between requests. Every request must contain all the information needed to process it. Our backend is stateless — it does not remember previous requests, does not have sessions, and does not store user data. Each GET /api/status is processed identically regardless of what came before.

**Q23: What is a 404 response and when does your backend return it?**
A: 404 Not Found means the requested resource does not exist on the server. Our backend returns 404 for any path other than / and /api/status. When a client requests /anything-else, the server responds with 404 and Cache-Control: no-store — errors are never cached. In a real application, 404 would indicate a missing page or endpoint.

**Q24: What is the purpose of the Content-Type header?**
A: Content-Type tells the client what format the response body is in. Our /api/status endpoint sets Content-Type: application/json so the client knows to parse the body as JSON. Without this header, the client would have to guess the format. Our / endpoint sets Content-Type: text/plain for the simple confirmation message.

**Q25: What cloud service is equivalent to your Backend A?**
A: Backend A is equivalent to an application server instance — in AWS an EC2 instance running an HTTP service, or an AWS Lambda function behind an API Gateway. In our project it is the compute layer that handles business logic and generates responses. The network infrastructure — DNS, load balancer, TLS — is separate from the application, exactly as it would be in production.

---

# SECTION 14 — FULL VIVA PREPARATION: VAIDEHI (Mac 4 — Backend B + Test Client)

---

## Phase 1 Viva Questions — Vaidehi

**Q1: Explain the entire project in simple terms.**
A: We built a private web service platform on four laptops on the same Wi-Fi. Mac 1 runs a private DNS server so our team domain resolves to the right machine. Mac 2 runs nginx which terminates HTTPS and load-balances traffic. Macs 3 and 4 run simple HTTP backends. A client types app.team1.test, DNS resolves it to Mac 2, a secure HTTPS connection is made, nginx picks either Backend A or B using round-robin, and the response comes back. Wireshark lets us see every step at the packet level.

**Q2: What is the complete flow of a single HTTPS request through your system?**
A: First, my Mac sends a DNS query to Om's Mac 1 asking for the IP of app.team1.test. dnsmasq replies with 10.7.17.151. My Mac opens a TCP connection to 10.7.17.151:8443 — three-way handshake. Then TLS negotiation: ClientHello, ServerHello, Certificate, key exchange, Finished. Then my encrypted HTTP GET request goes through the TLS tunnel to nginx. nginx decrypts it, picks a backend using round-robin, and sends plain HTTP to that backend. The backend responds. nginx encrypts the response and sends it back to me. I receive the JSON reply over HTTPS.

**Q3: What is your role as a test client?**
A: As the test client I make all the requests during the demo. My machine represents any end-user connecting to the service. I use curl because it shows headers and response details clearly. I run dig to prove DNS resolution, curl to prove HTTPS works, curl in a loop to prove load balancing, curl with If-None-Match to prove caching, and targeted curl commands during failure tests. I also run Backend B on my machine.

**Q4: What is the difference between a source port and a destination port?**
A: The destination port identifies the service on the remote machine — 8443 is always nginx's HTTPS port. The source port identifies my side of the connection — it is an ephemeral port randomly chosen by my OS, typically a high number above 49152. Every time I open a new TCP connection, a new ephemeral port is used. In Wireshark you see the same destination port 8443 every time, but a different source port each time.

**Q5: What does curl -sI do?**
A: curl -s means silent — suppresses progress output. curl -I means send a HEAD request — retrieve only the response headers, not the body. Together, `-sI` gives a clean output of just the HTTP headers. We use this to show Cache-Control, ETag, X-Backend, and HTTP status code without the JSON body cluttering the output.

**Q6: What does the -s flag do in curl? What does -v do?**
A: -s is silent mode — suppresses the progress meter and error messages so only the response is shown. -v is verbose mode — shows the full TLS negotiation, all request and response headers, and connection details. We use -s for clean output during the main demo and -v when we want to show TLS handshake details and certificate information.

**Q7: What is a 200 OK response?**
A: 200 OK is the standard HTTP success status code. It means the request was received, understood, and processed successfully. The response body contains the requested resource. In our case, 200 means nginx received the request, forwarded it to a backend, and the backend generated a valid response.

**Q8: What is the If-None-Match header and what does it trigger?**
A: If-None-Match is a conditional request header. The client sends it with the ETag of its cached copy. The server compares the client's ETag with its current version. If they match — nothing has changed — the server returns 304 Not Modified with no body. If they do not match — the resource changed — the server returns 200 with the new content and a new ETag. This is the conditional GET mechanism for efficient cache revalidation.

**Q9: Why does the X-Backend header sometimes show A and sometimes B?**
A: Because nginx is distributing requests across both backends using round-robin. Even though I am connecting to the same domain and same IP every time, nginx internally selects which backend handles each request. Backend A sets X-Backend: A and Backend B sets X-Backend: B. nginx passes this header through to me using proxy_pass_header. The alternating pattern proves load balancing is working.

**Q10: What does dig do and what does +short mean?**
A: dig is a DNS lookup tool. It queries a DNS server for records about a domain. `dig app.team1.test` sends a query for the A record of app.team1.test and shows the full DNS response including TTL, flags, and the answering server. The +short flag strips all that detail and shows only the resolved IP address. We use +short during the demo for clean, readable output.

**Q11: What is Wireshark and what layer does it operate at?**
A: Wireshark is a packet capture and analysis tool. It captures all network traffic passing through a network interface and lets you inspect individual packets. It operates at every layer — you can see Ethernet frames at Layer 2, IP packets at Layer 3, TCP segments at Layer 4, and TLS records at the session layer. For HTTPS traffic, Wireshark can see the TLS handshake messages but not the encrypted application payload.

**Q12: What does the Wireshark filter `tls.record.content_type == 23` show?**
A: TLS records have a content type field. Type 22 is Handshake records — ClientHello, ServerHello, Certificate. Type 23 is Application Data — the encrypted HTTP payload. Filtering for content type 23 shows only the actual encrypted HTTP exchanges, not the handshake. This lets us point to specific packets and say: this is the encrypted GET request and this is the encrypted response — proving the payload is protected.

**Q13: What is an ephemeral port and why does it change with every connection?**
A: An ephemeral port is a temporary port that the OS assigns to the client side of each outgoing connection. The OS picks a random unused port from the range 49152–65535. It is used only for the duration of that TCP connection. Each new connection gets a new ephemeral port. This is why in Wireshark you see the destination port always 8443 but the source port changes with each connection.

**Q14: Why is the HTTP payload invisible in Wireshark for HTTPS traffic?**
A: Because TLS encrypts the entire HTTP layer — method, URL, headers, and body. After the TLS handshake establishes a shared session key, every byte of HTTP data is encrypted using that key. Wireshark can see the IP and TCP headers because those are in plaintext — they are needed for network routing. But everything inside the TLS record is ciphertext. Only nginx and my machine have the session key to decrypt it.

**Q15: What is the purpose of the `--resolve` flag in curl?**
A: `--resolve app.team1.test:8443:10.7.17.151` tells curl to use a specific IP for a domain without consulting DNS. This is useful for testing when DNS is not working — you manually tell curl where to connect. During failure tests we sometimes use this to bypass DNS and test TCP/TLS directly. In the main demo we do not use it — the domain resolves normally through Om's DNS.

---

## Phase 2 / Full System Viva Questions — Vaidehi

**Q16: What is the full request flow from your machine to Backend B?**
A: My machine sends a DNS query to Om's Mac 1 — gets 10.7.17.151. Opens TCP to 10.7.17.151:8443. TLS handshake with nginx. Sends encrypted GET /api/status. nginx decrypts, selects Backend B via round-robin, opens TCP to 10.7.2.96:3002, sends plain HTTP GET. Backend B — on my own machine — receives the request on port 3002, returns {"backend":"B","status":"ok"} with headers. nginx receives this, encrypts the response, sends it back to me on port 8443. I receive it.

**Q17: What is backend service isolation and why would it matter?**
A: Service isolation means only nginx on Mac 2 can directly reach port 3002 on my machine. Currently, any machine on the LAN can curl http://10.7.2.96:3002/api/status directly — bypassing nginx, bypassing TLS, bypassing load balancing. In a real system this is a security and architecture violation. pf firewall rules would block direct access from all IPs except 10.7.17.151.

**Q18: What is DNS TTL and how does it relate to service migration?**
A: TTL is how long a DNS answer is cached. In production, before migrating a service to a new server, engineers lower the TTL to something like 60 seconds. Then they move the service. After the change, clients pick up the new DNS answer within 60 seconds. Without lowering the TTL first, clients might cache the old record for hours and keep hitting the old server. In our demo we would show this with a 30-second TTL.

**Q19: What is the difference between 502 and 503?**
A: 502 Bad Gateway means nginx connected to the backend but the backend returned an invalid response or the connection was refused — typically because the backend process is not running. 503 Service Unavailable means nginx temporarily cannot handle the request — usually because all backends are marked as failed and in a cooldown period. Both originate from the nginx-to-backend layer but 502 is a direct connection failure and 503 is a capacity or cooldown issue.

**Q20: What would you check first if a faculty member breaks the system during the demo?**
A: I would follow the diagnostic order: DNS first. I run `dig app.team1.test +short`. If it returns 10.7.17.151, DNS is fine and I move to TCP. I run `nc -zv 10.7.17.151 8443`. If that succeeds, I move to TLS. I run `curl -sv https://app.team1.test:8443/health` and check for TLS errors. If TLS is fine, I check the application layer with `curl -s https://app.team1.test:8443/api/status` and look for 502. Each layer I check tells me whether to go deeper or investigate sideways.

**Q21: What is high availability and does your current setup achieve it?**
A: High availability means the service continues operating even when individual components fail. Our setup has partial HA — if one backend fails, the other takes over, so backend failure is handled. But if nginx on Mac 2 fails, the entire service goes down — that is a single point of failure. True HA at the edge would require a standby nginx with automatic DNS failover or a virtual IP shared between two nginx instances.

**Q22: What is the difference between load balancing and failover?**
A: Load balancing distributes traffic across multiple healthy backends to share the load — it is active under normal operation. Failover is what happens when one component fails — traffic is rerouted to the remaining healthy component. In our setup, nginx does both: it load-balances using round-robin during normal operation, and it fails over to Backend B when Backend A is unreachable.

**Q23: What is HTTPS and what does it protect against?**
A: HTTPS is HTTP inside a TLS tunnel. It protects against eavesdropping — anyone capturing traffic on the LAN cannot read the HTTP headers or body. It protects against tampering — TLS uses authenticated encryption so any modification of packets in transit is detected. It protects against impersonation — the certificate proves the server is who it claims to be. Without HTTPS, all credentials, tokens, and data in HTTP requests are visible in plaintext.

**Q24: What is the Content-Length header and why does it matter for caching?**
A: Content-Length tells the client how many bytes to expect in the response body. For our /api/status endpoint it is always 32 bytes — the length of {"backend": "A", "status": "ok"} or {"backend": "B", "status": "ok"}. In a 304 Not Modified response, Content-Length is absent — because there is no body. This is important: a client that sees 304 knows to use its cached body and not wait for new content.

**Q25: What would you say to a faculty member who asks why your project matters?**
A: This project demonstrates exactly how a real cloud service works — just scaled down to four laptops. When you visit any website, your request goes through DNS, TCP, TLS, a load balancer, and backend servers — exactly like our project. Understanding each layer — how DNS separates from TCP, how TLS protects data, how a reverse proxy hides backend topology, how caching reduces load — is fundamental to building, debugging, and operating real networked systems. We built it from scratch and can explain every packet.

---

---

# SECTION 15 — REHEARSAL PLAN

---

## REHEARSAL 1 — Technical Verification (No speaking, no demo)
**Goal:** Confirm every service starts and works before anyone rehearses a single word.
**Who:** All four members independently on their own machines.
**What to verify:**

**Om — Mac 1:**
```bash
# Start dnsmasq
sudo /opt/homebrew/sbin/dnsmasq -C ~/Documents/CN_Project/config/dnsmasq.conf

# Verify it is running
pgrep -fl dnsmasq

# Test it answers correctly
dig app.team1.test @10.7.15.236 +short
# Must return: 10.7.17.151
```

**Aditya — Mac 2:**
```bash
# Confirm nginx is running
brew services list | grep nginx

# Test locally
curl -sk https://127.0.0.1:8443/health
# Must return: {"edge":"mac2","status":"ok",...}

# Test nginx config syntax
nginx -t

# Open Wireshark — load evidence/script7/pcap/script7_capture.pcapng
# Confirm it loads and packets are visible
```

**Krishiv — Mac 3:**
```bash
# Start Backend A
cd /path/to/CN_Project && python3 backend_a/server.py

# Verify from his own machine
curl -s http://localhost:3001/api/status
# Must return: {"backend": "A", "status": "ok"}

# Verify cache headers
curl -sI http://localhost:3001/api/status
# Must show: Cache-Control: max-age=60 | ETag: "72db076608216f33"
```

**Vaidehi — Mac 4:**
```bash
# Start Backend B
cd /path/to/CN_Project && python3 backend_b/server.py

# Confirm DNS is pointing to Om's Mac
networksetup -getdnsservers Wi-Fi
# Must show: 10.7.15.236

# Full end-to-end test — the most important check
curl -s https://app.team1.test:8443/api/status
# Must return JSON without -k and without certificate warning

# Confirm round-robin
for i in {1..6}; do curl -s https://app.team1.test:8443/api/status; echo; done
# Must show alternating A and B
```

**Pass condition:** All checks pass on all four machines. No service starts during the demo.

---

## REHEARSAL 2 — Commands + Handoffs (No full dialogue, just actions)
**Goal:** Every person practices the exact commands they type. Handoffs are rehearsed.
**Who:** All four together, connected to the same LAN.
**What to practice:**

1. Vaidehi types every command in the demo script in order — confirming each output matches expected.
2. Aditya practices opening Wireshark, loading the pcap, and applying each of the four filters in sequence: `dns` → `tcp.port == 8443` → `tls` → `tls.record.content_type == 23`.
3. Krishiv practices Ctrl+C (stop backend) and restarting — timed so there is no delay when Vaidehi gives the cue.
4. Screen handoffs are practiced physically: Vaidehi → Aditya (Wireshark) → Vaidehi → Om (Phase 2) → Vaidehi.
5. Every cue phrase from the Cue Sheet in Section 7 is said out loud and acted on.

**Pass condition:** No improvisation. Every handoff happens within 3 seconds of the cue phrase.

---

## REHEARSAL 3 — Full Timed Demo (Complete run-through)
**Goal:** Run the entire 11-step demo from start to finish without stopping.
**Who:** All four. One person plays "faculty" and watches.
**Time target:** 12–15 minutes for the demo portion. Leave 15 minutes for viva.
**What to practice:**

- Vaidehi speaks every line from Section 6 without reading it verbatim — she knows it well enough to sound natural.
- No one corrects Vaidehi mid-sentence. If she makes a small error, she corrects herself and moves on.
- Aditya applies Wireshark filters exactly on cue — no early, no late.
- Krishiv stops and restarts Backend A exactly on cue — smooth, no hesitation.
- Time each step. If any step takes more than 3 minutes, trim the dialogue.
- After the demo, the "faculty" person asks 3 random viva questions to each member.

**Pass condition:** Full demo completes within 15 minutes. Each viva answer is delivered confidently in under 60 seconds.

---

## REHEARSAL 4 — Fault Injection + Recovery
**Goal:** Practice diagnosing unexpected failures under pressure.
**Who:** All four. One person injects faults without telling the others what they changed.
**Faults to inject (rotate through these):**

| Fault | Who injects | How |
|---|---|---|
| Stop dnsmasq | Om | `sudo killall dnsmasq` |
| Change DNS record to wrong IP | Om | Edit dnsmasq.conf, change 10.7.17.151 to 10.7.17.99, restart |
| Stop nginx | Aditya | `brew services stop nginx` |
| Stop Backend A | Krishiv | Ctrl+C in Backend A terminal |
| Stop Backend B | Vaidehi | Ctrl+C in Backend B terminal |
| Change nginx upstream port | Aditya | Edit team.conf, change 3001 to 3099, `nginx -s reload` |

**For each fault:**
1. Vaidehi notices something is wrong from a failed curl.
2. She says: "I am now running through the diagnostic order — DNS first."
3. She runs the 4-layer diagnostic from Section 9.
4. She identifies the layer and points to the responsible machine.
5. That teammate fixes it.
6. Vaidehi confirms recovery with a successful curl.

**Pass condition:** Every fault is correctly diagnosed at the right layer within 2 minutes.

---

## REHEARSAL 5 — Individual Viva Practice
**Goal:** Every person can answer any question about the entire system — not just their own component.
**Who:** Pairs. Each person questions their partner.
**How:**

- Round 1: Om questions Vaidehi. Krishiv questions Aditya.
- Round 2: Aditya questions Om. Vaidehi questions Krishiv.
- Round 3: Random — anyone questions anyone.
- Draw questions randomly from Sections 11–14.
- Time each answer — target 30–45 seconds per question.
- After each answer, the questioner gives brief feedback: "Good" / "Too long" / "Missing X".

**Pass condition:** Every person answers at least 10 questions across all four role areas without reading from notes.

---

# SECTION 16 — FINAL ONE-PAGE CHEAT SHEET

> Print this. Keep it face-down on the table. Look at it only if completely stuck.

```
═══════════════════════════════════════════════════════
  CN PROJECT — TEAM 1 — PHASE 1 CHEAT SHEET
═══════════════════════════════════════════════════════

ARCHITECTURE
  Client → DNS (Mac 1) → TCP → TLS → nginx (Mac 2)
         → round-robin → Backend A (Mac 3)
                       → Backend B (Mac 4)

REAL IPs
  Om    Mac 1  DNS       10.7.15.236   :53/UDP
  Aditya Mac 2  nginx     10.7.17.151   :8443/TCP (HTTPS)
                                        :8080/TCP (HTTP→redirect)
  Krishiv Mac 3  Backend A 10.7.16.201    :3001/TCP
  Vaidehi Mac 4  Backend B 10.7.2.96   :3002/TCP

DOMAIN:   app.team1.test → 10.7.17.151
NETWORK:  10.7.0.0/19   GATEWAY: 10.7.0.1

KEY COMMANDS (Vaidehi types these)
  dig app.team1.test +short          → 10.7.17.151
  dig app.team1.test @8.8.8.8 +short → (empty)
  curl -s  https://app.team1.test:8443/api/status
  curl -sI https://app.team1.test:8443/api/status
  for i in {1..8}; do curl -s https://app.team1.test:8443/api/status; echo; done
  curl -sI -H 'If-None-Match: "72db076608216f33"' https://app.team1.test:8443/api/status

WIRESHARK FILTERS (Aditya applies on cue)
  dns
  tcp.port == 8443
  tls
  tls.record.content_type == 23

IMPORTANT HEADERS
  X-Backend: A / B       → which backend served this
  Cache-Control: max-age=60 → cache for 60 seconds
  ETag: "72db076608216f33" → Backend A fingerprint
  ETag: "backend-b-v1"    → Backend B fingerprint
  304 Not Modified         → cache is still fresh, no body

TLS HANDSHAKE (speak this order)
  ClientHello → ServerHello → Certificate
  → Key Exchange → Finished → Encrypted

DIAGNOSTIC ORDER (always this sequence)
  1. DNS:  dig app.team1.test +short
  2. TCP:  nc -zv 10.7.17.151 8443
  3. TLS:  curl -sv https://app.team1.test:8443/health 2>&1 | grep TLS
  4. APP:  curl -s https://app.team1.test:8443/api/status

ERROR MEANINGS
  Empty dig result       → DNS broken  (check dnsmasq)
  Connection refused     → nginx down  (check brew services)
  SSL certificate error  → cert issue  (check nginx config)
  502 Bad Gateway        → both backends down

SERVICE START COMMANDS
  Om:      sudo /opt/homebrew/sbin/dnsmasq -C ~/Documents/CN_Project/config/dnsmasq.conf
  Aditya:  brew services start nginx
  Krishiv: python3 backend_a/server.py
  Vaidehi: python3 backend_b/server.py

CUES
  "Aditya, please take the screen"           → Aditya connects to projector
  "Aditya, please apply the filter: dns"     → Aditya types dns
  "Krishiv, please stop Backend A now"       → Krishiv presses Ctrl+C
  "Krishiv, please start Backend A again"    → Krishiv runs python3 backend_a/server.py
  "Aditya, I will take the screen back"      → Aditya returns projector to Vaidehi
═══════════════════════════════════════════════════════
```

---

# SECTION 17 — FINAL PROJECT COVERAGE CHECKLIST

> Verify every required demo point is covered before the evaluation.
> Check each box during Rehearsal 3.

## Phase 1 Mandatory Tasks (50 marks)

### Task A — Private LAN (part of 10 marks with Task B)
- [ ] All four machine IPs confirmed on 10.7.0.0/19 subnet
- [ ] Ping from Mac 4 to Mac 1 (10.7.15.236) succeeds
- [ ] Ping from Mac 4 to Mac 2 (10.7.17.151) succeeds
- [ ] Ping from Mac 4 to Mac 3 (10.7.16.201) succeeds
- [ ] Topology diagram visible during Step 1

### Task B — Private DNS (part of 10 marks with Task A)
- [ ] dnsmasq running on Mac 1
- [ ] `dig app.team1.test +short` returns 10.7.17.151 from Mac 4
- [ ] `dig app.team1.test @8.8.8.8 +short` returns nothing (proves private DNS)
- [ ] Client DNS configured to use 10.7.15.236 (`networksetup -getdnsservers Wi-Fi`)
- [ ] .test namespace explained (not .local, not .com)
- [ ] DNS vs TCP connection difference explained

### Task C + D — Backends + Reverse Proxy + Load Balancing (10 marks)
- [ ] `curl -s http://10.7.16.201:3001/api/status` returns {"backend":"A","status":"ok"}
- [ ] `curl -s http://10.7.2.96:3002/api/status` returns {"backend":"B","status":"ok"}
- [ ] `curl -sI https://app.team1.test:8443/api/status` shows Server: nginx
- [ ] X-Backend: A observed in at least one response
- [ ] X-Backend: B observed in at least one response
- [ ] 8-request loop shows round-robin distribution
- [ ] nginx upstream config explained (backend_nodes block)
- [ ] Client never uses backend IPs directly in the demo

### Task E — HTTPS / TLS (8 marks)
- [ ] `curl -s https://app.team1.test:8443/api/status` succeeds without -k
- [ ] TLS version shown: TLSv1.3
- [ ] Certificate subject shown: CN=app.team1.test
- [ ] TLS handshake steps explained: ClientHello → ServerHello → Cert → Key Exchange → Finished
- [ ] TLS termination at nginx explained (backends receive plain HTTP)
- [ ] HTTP → HTTPS redirect from port 8080 to 8443 mentioned

### Task F — HTTP Caching (5 marks)
- [ ] `curl -sI` shows Cache-Control: max-age=60
- [ ] `curl -sI` shows ETag header
- [ ] Conditional request with If-None-Match demonstrated
- [ ] 304 Not Modified response shown
- [ ] Three-stage caching model explained: fresh hit / conditional / full request
- [ ] Cache-Control: no-store on errors mentioned

### Task G — Wireshark Packet Evidence (7 marks)
- [ ] Wireshark pcap loaded: evidence/script7/pcap/script7_capture.pcapng
- [ ] DNS query packet identified: source → 10.7.15.236:53
- [ ] DNS response packet identified: answer app.team1.test → 10.7.17.151
- [ ] TCP SYN packet identified with destination port 8443
- [ ] TCP SYN-ACK packet identified
- [ ] TCP ACK packet identified
- [ ] TLS ClientHello identified with SNI = app.team1.test
- [ ] TLS ServerHello + Certificate identified
- [ ] Application Data packets (type 23) shown — content invisible
- [ ] Ephemeral source port explained
- [ ] UDP port 53 explained for DNS
- [ ] Why payload is invisible explained (TLS encryption)

### Phase 1 Failure Tests (part of overall assessment)
- [ ] Test 1: Wrong DNS server — `dig @8.8.8.8` returns nothing
- [ ] Test 2: Wrong DNS record — TCP connection times out to wrong IP
- [ ] Test 3: Stop Backend A — all responses come from B only
- [ ] Test 4: Wrong port — connection refused to port 9999
- [ ] Layer of each failure correctly identified: DNS / TCP / Application / TCP

### Individual Viva (10 marks per person)
- [ ] Om ready to answer 25 questions (Sections 11)
- [ ] Aditya ready to answer 25 questions (Section 12)
- [ ] Krishiv ready to answer 25 questions (Section 13)
- [ ] Vaidehi ready to answer 25 questions (Section 14)
- [ ] Every person can explain components outside their assigned role

## Demonstration Sequence Checklist (11 Steps from Project Spec)
- [ ] Step 1: Topology and IP/service inventory shown ✓
- [ ] Step 2: All machines confirmed on private LAN ✓
- [ ] Step 3: Private domain resolved from client ✓
- [ ] Step 4: Service opened over HTTPS using domain name ✓
- [ ] Step 5: Load balancing shown — X-Backend A and B both observed ✓
- [ ] Step 6: Wireshark evidence — DNS, TCP handshake, TLS handshake shown ✓
- [ ] Step 7: HTTP caching headers and 304 shown ✓
- [ ] Step 8: One backend stopped — service continues through other ✓
- [ ] Step 9: Phase 2 extensions described (Extension D demonstrated) ✓
- [ ] Step 10: Fault diagnosis procedure rehearsed ✓
- [ ] Step 11: Individual viva preparation complete ✓

## Evidence Files Ready
- [ ] `evidence/script7/pcap/script7_capture.pcapng` — Wireshark capture loaded and tested
- [ ] `evidence/script7/screenshots/` — TCP handshake, TLS handshake, encrypted data screenshots
- [ ] `evidence/script7/curl_output/` — verbose curl outputs saved
- [ ] `evidence/script8/` — failure test outputs saved
- [ ] `configs/nginx/nginx_https.conf` — nginx config ready to show
- [ ] `config/dnsmasq.conf` — dnsmasq config ready to show
- [ ] `backend_a/server.py` — Backend A code ready to show
- [ ] `backend_b/server.py` — Backend B code ready to show
- [ ] `docs/topology.md` — topology diagram ready to show
- [ ] `CN_PROJECT_LIVE_CONFIG.md` — live config summary ready to show

## Pre-Demo Final Checks (run 10 minutes before faculty arrives)
```bash
# Mac 1 — Om
pgrep -fl dnsmasq || echo "START DNSMASQ NOW"

# Mac 2 — Aditya
brew services list | grep nginx | grep started || echo "START NGINX NOW"
curl -sk https://127.0.0.1:8443/health | grep ok || echo "NGINX NOT RESPONDING"

# Mac 3 — Krishiv
curl -s http://10.7.16.201:3001/api/status | grep backend || echo "START BACKEND A NOW"

# Mac 4 — Vaidehi
curl -s https://app.team1.test:8443/api/status | grep backend || echo "END TO END BROKEN"
```

If the last command on Mac 4 returns a backend response — everything is ready.

---

*End of CN Project Final Demonstration + Viva Script*
*Team 1 | Phase 1 Complete | app.team1.test | 10.7.0.0/19*
