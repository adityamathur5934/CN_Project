# Extension C — Backend B Isolation: Pre-Change Audit

## Audit Timestamp
2025-07-16 (run at workflow step execution time on Mac 4)

---

## Mac 4 Identity

| Item | Value |
|------|-------|
| Hostname | Mac 4 (Vaidehi) |
| Primary IP | `10.7.2.96` |
| Interface | `en0` |
| Network | `10.7.0.0/19` (netmask `0xffffe000`, broadcast `10.7.31.255`) |

**ifconfig en0 output:**
```
inet6 fe80::1080:78b4:4dc:790c%en0 prefixlen 64 secured scopeid 0xb
inet 10.7.2.96 netmask 0xffffe000 broadcast 10.7.31.255
```

---

## TCP 3002 — Listening Process

**lsof -iTCP:3002 -sTCP:LISTEN output:**
```
COMMAND   PID        USER   FD   TYPE             DEVICE SIZE/OFF NODE NAME
Python  20356 vaidehisahu    4u  IPv4 0xd1d2588d2eec2aca      0t0  TCP *:exlm-agent (LISTEN)
```

| Item | Value |
|------|-------|
| Process | `Python` (PID 20356) |
| User | `vaidehisahu` |
| Bind address | `*` (0.0.0.0 — all interfaces) |
| Port | 3002 (`exlm-agent`) |

**server.py confirms:** `HOST = "0.0.0.0"`, `PORT = 3002`

**netstat -an | grep 3002 output:**
```
tcp4       0      0  *.3002                 *.*                    LISTEN
46d928866d03a558 stream      0      0                0 ad3002e38bbc0548                0                0 /var/run/mDNSResponder
ad3002e38bbc0548 stream      0      0                0 46d928866d03a558                0                0
```

The `tcp4` row confirms Backend B is bound to `0.0.0.0:3002` (all interfaces).

---

## pf (Packet Filter) State

**pfctl requires root; sudo was not available interactively in this session.**

**pfctl -s nat output (Apple system anchors only):**
```
nat-anchor "com.apple/*" all
rdr-anchor "com.apple/*" all
```

**pfctl -s References:**
```
No pf starter references held
```

**pfctl -s info:** Permission denied (pf accessible only as root)

**pf status assessment:** pf's Apple system anchors are present (loaded at boot), but no
application-level rules or anchors are active. No rules currently restrict port 3002.

**Current /etc/pf.conf (verbatim):**
```
#
# Default PF configuration file.
#
# This file contains the main ruleset, which gets automatically loaded
# at startup.  PF will not be automatically enabled, however.  Instead,
# each component which utilizes PF is responsible for enabling and disabling
# PF via -E and -X as documented in pfctl(8).  That will ensure that PF
# is disabled only when the last enable reference is released.
#
# Care must be taken to ensure that the main ruleset does not get flushed,
# as the nested anchors rely on the anchor point defined here. In addition,
# to the anchors loaded by this file, some system services would dynamically
# insert anchors into the main ruleset. These anchors will be added only when
# the system service is used and would removed on termination of the service.
#
# See pf.conf(5) for syntax.
#
#
# com.apple anchor point
#
scrub-anchor "com.apple/*"
nat-anchor "com.apple/*"
rdr-anchor "com.apple/*"
dummynet-anchor "com.apple/*"
anchor "com.apple/*"
load anchor "com.apple" from "/etc/pf.anchors/com.apple"
```

**Active anchors (pfctl -s References):**
```
No pf starter references held
```

---

## Reachability Assessment (Pre-Change)

**Status: UNRESTRICTED**

Because no pf rules restrict TCP port 3002, and Backend B binds to `0.0.0.0:3002`:

- Any host on `10.7.0.0/19` can reach Backend B directly on `10.7.2.96:3002`
- Mac 2 (nginx proxy, `10.7.11.31`) can reach it ✅ (required)
- Mac 1 (`10.7.10.8`), Mac 3 (`10.7.28.25`), and any other LAN host can also reach it ⚠️ (must be blocked by Extension C)

---

## Required Change

Install a macOS pf anchor `com.cn-project.backend-b-isolation` that:
1. Passes loopback traffic on `lo0` → `127.0.0.1:3002`
2. Passes inbound on `en0` from `10.7.11.31` (Mac 2 nginx) → port 3002
3. Blocks all other inbound on `en0` → port 3002

Artifacts authored in `/Users/vaidehisahu/CN/evidence/phase2/`.
**Rules are not yet active** — activation requires Aditya to confirm `MAC2_IP=10.7.11.31`.
