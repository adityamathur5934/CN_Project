#!/usr/bin/env zsh
# =============================================================================
# phase2_backup_dns.sh — Extension A: Backup DNS Failover Demonstration
# Machine: Mac 1 (Om) / Client
# Usage: ./scripts/phase2_backup_dns.sh <BACKUP_DNS_IP>
# Example: ./scripts/phase2_backup_dns.sh 10.7.2.96
# =============================================================================

PRIMARY_DNS="10.7.10.8"
BACKUP_DNS="${1:-10.7.2.96}"
DOMAIN="app.team1.test"

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; BOLD='\033[1m'; RESET='\033[0m'
pass() { echo "${GREEN}  ✅ PASS${RESET} — $1"; }
fail() { echo "${RED}  ❌ FAIL${RESET} — $1"; }
info() { echo "${YELLOW}  ℹ${RESET}  $1"; }

echo ""
echo "${BOLD}═══════════════════════════════════════════════════════════${RESET}"
echo "${BOLD}  Phase 2 Extension A — Backup DNS Failover Verification   ${RESET}"
echo "${BOLD}  Primary: ${PRIMARY_DNS} | Backup: ${BACKUP_DNS}          ${RESET}"
echo "${BOLD}═══════════════════════════════════════════════════════════${RESET}"
echo ""

echo "${BOLD}[1/3] Testing Primary DNS (${PRIMARY_DNS})...${RESET}"
if PRIM_RES=$(dig +short "${DOMAIN}" "@${PRIMARY_DNS}" 2>/dev/null); then
  pass "Primary DNS responded: ${DOMAIN} -> ${PRIM_RES}"
else
  fail "Primary DNS (${PRIMARY_DNS}) did not respond"
fi

echo ""
echo "${BOLD}[2/3] Testing Backup DNS (${BACKUP_DNS})...${RESET}"
if BACK_RES=$(dig +short "${DOMAIN}" "@${BACKUP_DNS}" 2>/dev/null); then
  pass "Backup DNS responded: ${DOMAIN} -> ${BACK_RES}"
else
  fail "Backup DNS (${BACKUP_DNS}) not responding. (Ensure secondary dnsmasq is running on ${BACKUP_DNS})"
fi

echo ""
echo "${BOLD}[3/3] Failover Simulation Checklist for Viva:${RESET}"
echo "  Step 1: Configure client resolver with BOTH resolvers:"
echo "          Primary: ${PRIMARY_DNS}, Secondary: ${BACKUP_DNS}"
echo "  Step 2: Verify normal resolution:"
echo "          dig ${DOMAIN} (Resolved by ${PRIMARY_DNS})"
echo "  Step 3: Simulate Primary DNS failure:"
echo "          sudo killall dnsmasq   (run on Mac 1)"
echo "  Step 4: Prove failover still works:"
echo "          dig ${DOMAIN} @${BACKUP_DNS}"
echo "          Notice the answer section: SERVER: ${BACKUP_DNS}#53"
echo "  Step 5: Restore Primary DNS:"
echo "          sudo /opt/homebrew/sbin/dnsmasq -C config/dnsmasq.conf"
echo ""
echo "${BOLD}═══════════════════════════════════════════════════════════${RESET}"
