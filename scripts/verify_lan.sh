#!/usr/bin/env zsh
# =============================================================================
# verify_lan.sh — Script 0 Pairwise LAN Reachability Check
# Machine: Mac 2 (P2) | IP: 10.7.17.151
# Usage:   ./scripts/verify_lan.sh <P1_IP> <P3_IP> <P4_IP>
# Example: ./scripts/verify_lan.sh 10.7.5.20 10.7.8.45 10.7.12.99
# =============================================================================

set -euo pipefail

# ── Colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
RESET='\033[0m'

pass() { echo "${GREEN}  ✅ PASS${RESET} — $1"; }
fail() { echo "${RED}  ❌ FAIL${RESET} — $1"; }
info() { echo "${BLUE}  ℹ${RESET}  $1"; }
warn() { echo "${YELLOW}  ⚠${RESET}  $1"; }

# ── Usage check ──────────────────────────────────────────────────────────────
if [[ $# -ne 3 ]]; then
  echo ""
  echo "${BOLD}Usage:${RESET} $0 <P1_IP> <P3_IP> <P4_IP>"
  echo ""
  echo "  P1_IP — Mac 1 (DNS Server)"
  echo "  P3_IP — Mac 3 (Backend A, port 3001)"
  echo "  P4_IP — Mac 4 (Backend B, port 3002)"
  echo ""
  echo "${BOLD}Example:${RESET}"
  echo "  $0 10.7.5.20 10.7.8.45 10.7.12.99"
  echo ""
  exit 1
fi

P1_IP="$1"
P3_IP="$2"
P4_IP="$3"
MAC2_IP="10.7.17.151"
SUBNET="10.7.0.0/19"
GATEWAY="10.7.0.1"

echo ""
echo "${BOLD}═══════════════════════════════════════════════════════════${RESET}"
echo "${BOLD}  Script 0 — LAN Reachability Check  |  Mac 2 (P2)${RESET}"
echo "${BOLD}═══════════════════════════════════════════════════════════${RESET}"
echo ""

# ── Step 1: Confirm this Mac's own LAN address ───────────────────────────────
echo "${BOLD}[1/5] Confirming Mac 2 LAN address${RESET}"
ACTUAL_IP=$(ipconfig getifaddr en0 2>/dev/null || echo "UNKNOWN")
if [[ "$ACTUAL_IP" == "$MAC2_IP" ]]; then
  pass "Mac 2 IP is ${MAC2_IP} on en0"
else
  warn "Expected ${MAC2_IP} but got ${ACTUAL_IP} on en0"
  warn "Continuing with detected IP: ${ACTUAL_IP}"
  MAC2_IP="$ACTUAL_IP"
fi

# ── Validate all IPs are in the same /19 subnet ──────────────────────────────
echo ""
echo "${BOLD}[2/5] Subnet membership check (all must be in ${SUBNET})${RESET}"

check_subnet() {
  local ip="$1"
  local label="$2"
  # Extract the /19 prefix: 10.7.0–31.x  → first two octets 10.7, third 0–31
  local oct3
  oct3=$(echo "$ip" | awk -F. '{print $3}')
  local prefix
  prefix=$(echo "$ip" | awk -F. '{print $1"."$2}')
  if [[ "$prefix" == "10.7" ]] && (( oct3 >= 0 && oct3 <= 31 )); then
    pass "${label} (${ip}) is in ${SUBNET}"
  else
    fail "${label} (${ip}) does NOT appear to be in ${SUBNET} — check if all Macs are on the same network"
  fi
}

check_subnet "$MAC2_IP" "Mac 2 (P2 — YOU)"
check_subnet "$P1_IP"   "Mac 1 (P1 — DNS)"
check_subnet "$P3_IP"   "Mac 3 (P3 — Backend A)"
check_subnet "$P4_IP"   "Mac 4 (P4 — Backend B)"

# ── Step 3: Ping each target ─────────────────────────────────────────────────
echo ""
echo "${BOLD}[3/5] Pairwise ping verification${RESET}"

ping_check() {
  local target="$1"
  local label="$2"
  echo -n "  Pinging ${label} (${target}) ... "
  if ping -c 3 -W 2000 "$target" &>/dev/null; then
    RTT=$(ping -c 3 -W 2000 "$target" 2>/dev/null | tail -1 | awk -F'/' '{print $5}' 2>/dev/null || echo "?")
    pass "${label} (${target}) — avg RTT: ${RTT}ms"
  else
    fail "${label} (${target}) — no response"
    echo "     ${YELLOW}Troubleshoot:${RESET}"
    echo "       1. Confirm ${target} is the correct IP for ${label}"
    echo "       2. Check both Macs are on the same Wi-Fi/LAN"
    echo "       3. Check firewall on target: sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getblockall"
    echo "       4. Try ARP check: arp -n ${target}"
  fi
}

ping_check "$P1_IP" "Mac 1 — P1 (DNS)"
ping_check "$P3_IP" "Mac 3 — P3 (Backend A)"
ping_check "$P4_IP" "Mac 4 — P4 (Backend B)"

# ── Step 4: ARP layer-2 check ────────────────────────────────────────────────
echo ""
echo "${BOLD}[4/5] ARP layer-2 reachability check${RESET}"

arp_check() {
  local target="$1"
  local label="$2"
  # Send a single ping first to populate ARP cache
  ping -c 1 -W 1000 "$target" &>/dev/null || true
  ARP_ENTRY=$(arp -n "$target" 2>/dev/null | grep -v "no entry" || echo "")
  if [[ -n "$ARP_ENTRY" ]]; then
    MAC_FOUND=$(echo "$ARP_ENTRY" | awk '{print $2}')
    pass "${label} ARP entry found: ${MAC_FOUND}"
  else
    fail "${label} (${target}) — no ARP entry (Layer 2 not reachable or different subnet)"
  fi
}

arp_check "$GATEWAY" "Gateway (${GATEWAY})"
arp_check "$P1_IP"   "Mac 1 — P1"
arp_check "$P3_IP"   "Mac 3 — P3"
arp_check "$P4_IP"   "Mac 4 — P4"

# ── Step 5: Summary ──────────────────────────────────────────────────────────
echo ""
echo "${BOLD}[5/5] Script 0 Summary${RESET}"
echo ""
echo "  ${BOLD}Mac 2 (P2 — YOU):${RESET}"
echo "    IP:         ${MAC2_IP}"
echo "    Interface:  en0"
echo "    Subnet:     ${SUBNET}"
echo "    Gateway:    ${GATEWAY}"
echo "    Role:       Edge / nginx / TLS / Load Balancer"
echo "    Service:    Port 443 (HTTPS), Port 80 (HTTP)"
echo ""
echo "  ${BOLD}Team IPs provided:${RESET}"
echo "    Mac 1 (P1 — DNS):       ${P1_IP}  :53"
echo "    Mac 3 (P3 — Backend A): ${P3_IP}  :3001"
echo "    Mac 4 (P4 — Backend B): ${P4_IP}  :3002"
echo ""
echo "  ${BOLD}Domain plan:${RESET} app.team.test → ${MAC2_IP}"
echo ""
echo "${BOLD}═══════════════════════════════════════════════════════════${RESET}"
echo "${BOLD}  Done condition: All pings pass = Script 0 COMPLETE${RESET}"
echo "${BOLD}  Next step for P2: Wait for Script 1 (P1 DNS) +${RESET}"
echo "${BOLD}  Scripts 2/3 (P3/P4 Backends), then run Script 4${RESET}"
echo "${BOLD}═══════════════════════════════════════════════════════════${RESET}"
echo ""
