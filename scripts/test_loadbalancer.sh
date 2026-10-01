#!/usr/bin/env zsh
# =============================================================================
# test_loadbalancer.sh — Script 4: Round-robin load balancer verification
# Mac 2 (P2 — Aditya) | Run after both backends are confirmed up
# Usage: ./scripts/test_loadbalancer.sh
# =============================================================================

EDGE_IP="10.7.17.151"
EDGE_PORT="8080"
DOMAIN="app.team.test"
REQUESTS=10

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; BOLD='\033[1m'; RESET='\033[0m'
pass() { echo "${GREEN}  ✅ PASS${RESET} — $1"; }
fail() { echo "${RED}  ❌ FAIL${RESET} — $1"; }
warn() { echo "${YELLOW}  ⚠${RESET}  $1"; }

echo ""
echo "${BOLD}═══════════════════════════════════════════════════════════${RESET}"
echo "${BOLD}  Script 4 — nginx Load Balancer Test  |  Mac 2 (P2)${RESET}"
echo "${BOLD}  Sending ${REQUESTS} requests to http://${EDGE_IP}:${EDGE_PORT}${RESET}"
echo "${BOLD}═══════════════════════════════════════════════════════════${RESET}"
echo ""

COUNT_A=0
COUNT_B=0
COUNT_ERR=0

for i in $(seq 1 $REQUESTS); do
  RESULT=$(curl -s -D - --connect-timeout 5 -H "Host: ${DOMAIN}" \
    "http://${EDGE_IP}:${EDGE_PORT}/api/status" 2>/dev/null)
  HTTP_CODE=$(echo "$RESULT" | grep "^HTTP" | awk '{print $2}')
  BODY=$(echo "$RESULT" | tail -1)
  XBACKEND=$(echo "$RESULT" | grep -i "x-backend" | tr -d '\r' | awk '{print $2}')

  if [[ "$HTTP_CODE" == "200" && -n "$XBACKEND" ]]; then
    echo "  Request $(printf '%2d' $i) → ${BOLD}X-Backend: ${XBACKEND}${RESET}  |  ${BODY}"
    [[ "$XBACKEND" == "A" ]] && (( COUNT_A++ ))
    [[ "$XBACKEND" == "B" ]] && (( COUNT_B++ ))
  else
    echo "  Request $(printf '%2d' $i) → ${RED}ERROR${RESET}  HTTP: ${HTTP_CODE:-none}  body: ${BODY}"
    (( COUNT_ERR++ ))
  fi
done

echo ""
echo "${BOLD}── Results ─────────────────────────────────────────────────${RESET}"
echo "  Total requests : ${REQUESTS}"
echo "  → Backend A    : ${COUNT_A}"
echo "  → Backend B    : ${COUNT_B}"
echo "  → Errors       : ${COUNT_ERR}"
echo ""

# Verdict
if (( COUNT_A > 0 && COUNT_B > 0 && COUNT_ERR == 0 )); then
  pass "Both backends served traffic — round-robin confirmed"
  pass "X-Backend: A seen ${COUNT_A} times"
  pass "X-Backend: B seen ${COUNT_B} times"
  echo ""
  echo "  ${BOLD}Script 4 DONE CONDITION MET ✅${RESET}"
  echo "  HTTP through app.team.test works and reaches both backends."
  echo "  Next step: Script 5 — HTTPS / TLS"
elif (( COUNT_A == 0 && COUNT_B > 0 )); then
  warn "Only Backend B served traffic — Backend A may be down"
  warn "Check on Mac 3: lsof -iTCP:3001 -sTCP:LISTEN"
elif (( COUNT_B == 0 && COUNT_A > 0 )); then
  warn "Only Backend A served traffic — Backend B may be down"
  warn "Check on Mac 4: lsof -iTCP:3002 -sTCP:LISTEN"
else
  fail "No successful responses — check nginx: brew services info nginx"
  fail "Check error log: tail /opt/homebrew/var/log/nginx/team_error.log"
fi

echo ""
echo "${BOLD}═══════════════════════════════════════════════════════════${RESET}"
echo ""
