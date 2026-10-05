#!/usr/bin/env zsh
# =============================================================================
# test_backends.sh — Script 4: Direct backend connectivity check
# Mac 2 (P2 — Aditya) | Run this before testing through nginx
# Usage: ./scripts/test_backends.sh
# =============================================================================

BACKEND_A="10.7.16.201:3001"
BACKEND_B="10.7.16.36:3002"
EDGE="10.7.17.151:8080"

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; BOLD='\033[1m'; RESET='\033[0m'
pass() { echo "${GREEN}  ✅ PASS${RESET} — $1"; }
fail() { echo "${RED}  ❌ FAIL${RESET} — $1"; }
warn() { echo "${YELLOW}  ⚠${RESET}  $1"; }

echo ""
echo "${BOLD}═══════════════════════════════════════════════════════════${RESET}"
echo "${BOLD}  Script 4 — Direct Backend Connectivity Check  |  Mac 2${RESET}"
echo "${BOLD}═══════════════════════════════════════════════════════════${RESET}"
echo ""

check_backend() {
  local label="$1"
  local host="$2"
  local port="$3"
  local expected_backend="$4"

  echo "${BOLD}[${label}] ${host}:${port}${RESET}"

  # 1. Ping
  IP="$host"
  if ping -c 1 -W 1000 "$IP" &>/dev/null; then
    pass "Ping ${IP} — network layer reachable"
  else
    fail "Ping ${IP} — host unreachable at network layer"
  fi

  # 2. TCP port
  RESPONSE=$(curl -s --connect-timeout 5 "http://${host}:${port}/api/status" 2>&1)
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "http://${host}:${port}/api/status" 2>/dev/null)

  if [[ "$HTTP_CODE" == "200" ]]; then
    pass "TCP connect to :${port} — HTTP 200 OK"
  else
    fail "TCP connect to :${port} — got HTTP ${HTTP_CODE} (or refused)"
    warn "Check: is the backend server process running on ${host}?"
    warn "Expected command on ${label}: python3 server.py  OR  node server.js"
    echo ""
    return
  fi

  # 3. Response body
  BACKEND_VAL=$(echo "$RESPONSE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('backend','?'))" 2>/dev/null)
  if [[ "$BACKEND_VAL" == "$expected_backend" ]]; then
    pass "Response body — backend: \"${BACKEND_VAL}\" ✓"
  else
    fail "Response body — expected backend \"${expected_backend}\", got \"${BACKEND_VAL}\""
  fi

  # 4. X-Backend header
  XBACKEND=$(curl -s -D - --connect-timeout 5 "http://${host}:${port}/api/status" -o /dev/null 2>/dev/null | grep -i "x-backend" | tr -d '\r' | awk '{print $2}')
  if [[ "$XBACKEND" == "$expected_backend" ]]; then
    pass "X-Backend header — \"${XBACKEND}\" ✓"
  else
    fail "X-Backend header — expected \"${expected_backend}\", got \"${XBACKEND:-missing}\""
  fi

  echo "  Full response: ${RESPONSE}"
  echo ""
}

check_backend "Backend A — Mac 3 Krishiv" "10.7.16.201" "3001" "A"
check_backend "Backend B — Mac 4 Vaidehi" "10.7.16.36" "3002" "B"

# Edge health check
echo "${BOLD}[Edge — Mac 2 nginx health]${RESET}"
EDGE_RESP=$(curl -s --connect-timeout 3 "http://${EDGE}/health")
if echo "$EDGE_RESP" | grep -q '"status":"ok"'; then
  pass "nginx edge health endpoint — ${EDGE_RESP}"
else
  fail "nginx edge not responding — ${EDGE_RESP}"
fi

echo ""
echo "${BOLD}═══════════════════════════════════════════════════════════${RESET}"
echo "${BOLD}  Done condition: Both backends pass all 4 checks above${RESET}"
echo "${BOLD}  Then run: ./scripts/test_loadbalancer.sh${RESET}"
echo "${BOLD}═══════════════════════════════════════════════════════════${RESET}"
echo ""
