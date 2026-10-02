#!/usr/bin/env zsh
# =============================================================================
# test_script9_dns.sh — Script 9: Backup DNS & TTL Verification Helper
# P1 / Client (Mac 4 — Vaidehi)
# Usage: ./scripts/test_script9_dns.sh
# =============================================================================

PRIMARY_DNS="10.7.15.236"
BACKUP_DNS="10.7.16.36"
DOMAIN="app.team1.test"

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; BOLD='\033[1m'; RESET='\033[0m'
pass() { echo "${GREEN}  ✅ PASS${RESET} — $1"; }
fail() { echo "${RED}  ❌ FAIL${RESET} — $1"; }
info() { echo "${YELLOW}  ℹ${RESET}  $1"; }

echo ""
echo "${BOLD}═══════════════════════════════════════════════════════════${RESET}"
echo "${BOLD}  Script 9 — Backup DNS & TTL Verification Helper         ${RESET}"
echo "${BOLD}  Domain: ${DOMAIN}${RESET}"
echo "${BOLD}═══════════════════════════════════════════════════════════${RESET}"
echo ""

# ── 1. Primary DNS Check ─────────────────────────────────────────────────────
echo "${BOLD}[1/4] Primary DNS Server (Mac 1: ${PRIMARY_DNS})${RESET}"
PRIM_OUT=$(dig @"$PRIMARY_DNS" +time=2 +tries=1 "$DOMAIN" +noall +answer 2>&1)
if echo "$PRIM_OUT" | grep -qi "10.7.17.151"; then
  pass "Primary DNS resolved: $PRIM_OUT"
else
  info "Primary DNS did not respond (may be stopped for failover testing):"
  echo "    $PRIM_OUT"
fi
echo ""

# ── 2. Backup DNS Check ─────────────────────────────────────────────────────
echo "${BOLD}[2/4] Backup DNS Server (Mac 4: ${BACKUP_DNS})${RESET}"
BACK_OUT=$(dig @"$BACKUP_DNS" +time=2 +tries=1 "$DOMAIN" +noall +answer 2>&1)
if echo "$BACK_OUT" | grep -qi "10.7.17.151"; then
  pass "Backup DNS resolved: $BACK_OUT"
else
  info "Backup DNS not running on port 53. To start:"
  echo "    sudo python3 dns/backup_dns.py"
fi
echo ""

# ── 3. Client Resolver Configuration Instructions ────────────────────────────
echo "${BOLD}[3/4] Client Resolver Multi-DNS Configuration${RESET}"
echo "  To configure macOS client with Primary + Backup DNS:"
echo "    sudo networksetup -setdnsservers Wi-Fi ${PRIMARY_DNS} ${BACKUP_DNS}"
echo ""
echo "  To revert client DNS back to DHCP defaults:"
echo "    sudo networksetup -setdnsservers Wi-Fi empty"
echo ""

# ── 4. TTL & Cache Flush Reference (Objective B) ─────────────────────────────
echo "${BOLD}[4/4] TTL Countdown & Cache Flush Demonstration${RESET}"
echo "  1. Observe TTL countdown in successive dig queries:"
echo "     dig ${DOMAIN} | grep -A 1 'ANSWER SECTION'"
echo ""
echo "  2. macOS DNS Cache Flush command:"
echo "     sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder"
echo ""
echo "${BOLD}═══════════════════════════════════════════════════════════${RESET}"
