#!/usr/bin/env zsh
# =============================================================================
# phase2_test_ttl.sh — Extension B: DNS TTL Verification & Cache Demonstration
# Machine: Mac 1 (Om) | DNS Resolver: 10.7.10.8:53
# =============================================================================

set -euo pipefail

DNS_IP="10.7.10.8"
DOMAIN="app.team1.test"

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; BOLD='\033[1m'; RESET='\033[0m'
pass() { echo "${GREEN}  ✅ PASS${RESET} — $1"; }
fail() { echo "${RED}  ❌ FAIL${RESET} — $1"; }
info() { echo "${YELLOW}  ℹ${RESET}  $1"; }

echo ""
echo "${BOLD}═══════════════════════════════════════════════════════════${RESET}"
echo "${BOLD}  Phase 2 Extension B — DNS TTL Verification              ${RESET}"
echo "${BOLD}  Target: ${DOMAIN} @ ${DNS_IP}                           ${RESET}"
echo "${BOLD}═══════════════════════════════════════════════════════════${RESET}"
echo ""

# 1. Query current record and extract TTL
echo "${BOLD}[1/3] Querying DNS record and inspecting TTL...${RESET}"
DIG_OUTPUT=$(dig +noall +answer "${DOMAIN}" "@${DNS_IP}")
echo "${DIG_OUTPUT}"
TTL=$(echo "${DIG_OUTPUT}" | awk '{print $2}')
ANSWER=$(echo "${DIG_OUTPUT}" | awk '{print $5}')

if [[ -n "$TTL" ]]; then
  pass "Record resolved: ${DOMAIN} -> ${ANSWER} with TTL = ${TTL}s"
else
  fail "Could not resolve ${DOMAIN} from ${DNS_IP}"
  exit 1
fi

if [[ "$TTL" -eq 30 ]]; then
  pass "TTL is exactly 30 seconds as specified in Extension B! ✅"
else
  info "Current TTL is ${TTL}s. (To set to 30s, ensure 'local-ttl=30' is in config/dnsmasq.conf and restart dnsmasq)"
fi

echo ""
echo "${BOLD}[2/3] Demonstrating Cache Expiration Simulation (TTL Countdown)...${RESET}"
echo "  Querying again after 5 seconds to observe cache behavior..."
sleep 5
DIG_SAMPLE=$(dig +noall +answer "${DOMAIN}" "@${DNS_IP}")
echo "  Second query answer: ${DIG_SAMPLE}"

echo ""
echo "${BOLD}[3/3] How to demonstrate Live Cutover & TTL Cache in Viva:${RESET}"
echo "  1. Query: dig ${DOMAIN} @${DNS_IP} (shows current edge IP with TTL 30)"
echo "  2. Edit config/dnsmasq.conf to change address: e.g. address=/${DOMAIN}/10.7.11.99"
echo "  3. Restart dnsmasq: sudo killall dnsmasq && sudo /opt/homebrew/sbin/dnsmasq -C config/dnsmasq.conf"
echo "  4. Client query: Cached client continues hitting old IP until 30s TTL expires"
echo "  5. After 30s (or flush: sudo dscacheutil -flushcache): client resolves new IP 10.7.11.99"
echo "  6. Rollback: change address back to 10.7.11.31 and restart dnsmasq"
echo ""
echo "${BOLD}═══════════════════════════════════════════════════════════${RESET}"
