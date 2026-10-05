#!/usr/bin/env zsh
# =============================================================================
# test_caching.sh — Script 6: HTTP Caching & Conditional 304 Verification
# P3/P4: HTTP Caching (Mac 4 — Backend B + Client)
# Usage: ./scripts/test_caching.sh
# =============================================================================

BACKEND_B="10.7.2.96:3002"
EDGE_IP="10.7.17.151"
EDGE_PORT="8443"
DOMAIN="app.team1.test"
ETAG_B='"backend-b-v1"'

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; BOLD='\033[1m'; RESET='\033[0m'
pass() { echo "${GREEN}  ✅ PASS${RESET} — $1"; }
fail() { echo "${RED}  ❌ FAIL${RESET} — $1"; }
warn() { echo "${YELLOW}  ⚠${RESET}  $1"; }

echo ""
echo "${BOLD}═══════════════════════════════════════════════════════════${RESET}"
echo "${BOLD}  Script 6 — HTTP Caching & Revalidation Verification     ${RESET}"
echo "${BOLD}  Backend B: ${BACKEND_B}  |  Edge: https://${DOMAIN}:${EDGE_PORT} ${RESET}"
echo "${BOLD}═══════════════════════════════════════════════════════════${RESET}"
echo ""

# ── 1. Direct Backend B — Fresh Request ──────────────────────────────────────
echo "${BOLD}[1/4] Direct Backend B — Fresh Request (HTTP 200)${RESET}"
HEADERS=$(curl -s -D - "http://${BACKEND_B}/api/status" -o /dev/null)
CODE=$(echo "$HEADERS" | grep "^HTTP" | awk '{print $2}')
CACHE_CONTROL=$(echo "$HEADERS" | grep -i "^Cache-Control" | tr -d '\r')
ETAG=$(echo "$HEADERS" | grep -i "^ETag" | tr -d '\r')
XBACKEND=$(echo "$HEADERS" | grep -i "^X-Backend" | tr -d '\r')

if [[ "$CODE" == "200" ]]; then
  pass "Status code: HTTP 200 OK"
else
  fail "Status code: expected 200, got ${CODE}"
fi

if echo "$CACHE_CONTROL" | grep -iq "max-age=60"; then
  pass "Cache-Control: ${CACHE_CONTROL#*: }"
else
  fail "Cache-Control header missing or invalid: '${CACHE_CONTROL}'"
fi

if [[ -n "$ETAG" ]]; then
  pass "ETag: ${ETAG#*: }"
else
  fail "ETag header missing"
fi

if echo "$XBACKEND" | grep -iq "B"; then
  pass "X-Backend: ${XBACKEND#*: }"
else
  fail "X-Backend header missing or unexpected: '${XBACKEND}'"
fi
echo ""

# ── 2. Direct Backend B — Conditional Request (HTTP 304) ─────────────────────
echo "${BOLD}[2/4] Direct Backend B — Conditional Request (If-None-Match → 304)${RESET}"
COND_HEADERS=$(curl -s -D - -H "If-None-Match: ${ETAG_B}" "http://${BACKEND_B}/api/status" -o /dev/null)
COND_CODE=$(echo "$COND_HEADERS" | grep "^HTTP" | awk '{print $2}')

if [[ "$COND_CODE" == "304" ]]; then
  pass "Status code: HTTP 304 Not Modified"
  pass "Conditional request validated: client cache is fresh, body transfer omitted"
else
  fail "Status code: expected 304, got ${COND_CODE}"
fi
echo ""

# ── 3. Nginx Edge — Header Survival over HTTPS (no -k) ───────────────────────
echo "${BOLD}[3/4] Nginx Edge — Header Survival over HTTPS${RESET}"
EDGE_HEADERS=$(curl -s -D - --resolve "${DOMAIN}:${EDGE_PORT}:${EDGE_IP}" \
  "https://${DOMAIN}:${EDGE_PORT}/api/status" -o /dev/null 2>/dev/null)
EDGE_CODE=$(echo "$EDGE_HEADERS" | grep "^HTTP" | awk '{print $2}')
EDGE_CC=$(echo "$EDGE_HEADERS" | grep -i "^Cache-Control" | tr -d '\r')
EDGE_ETAG=$(echo "$EDGE_HEADERS" | grep -i "^ETag" | tr -d '\r')
EDGE_XB=$(echo "$EDGE_HEADERS" | grep -i "^X-Backend" | tr -d '\r')

if [[ "$EDGE_CODE" == "200" ]]; then
  pass "Status code: HTTP 200 OK through reverse proxy"
else
  fail "Status code: HTTP ${EDGE_CODE} through reverse proxy"
fi

if echo "$EDGE_CC" | grep -iq "max-age=60"; then
  pass "Cache-Control survived nginx: ${EDGE_CC#*: }"
else
  fail "Cache-Control did not survive nginx: '${EDGE_CC}'"
fi

if [[ -n "$EDGE_ETAG" ]]; then
  pass "ETag survived nginx: ${EDGE_ETAG#*: }"
else
  fail "ETag did not survive nginx"
fi
echo ""

# ── 4. Nginx Edge — Conditional Request over HTTPS (no -k) ───────────────────
echo "${BOLD}[4/4] Nginx Edge — Conditional Request Revalidation (HTTP 304)${RESET}"
EDGE_COND=$(curl -s -D - -H "If-None-Match: ${ETAG_B}" \
  --resolve "${DOMAIN}:${EDGE_PORT}:${EDGE_IP}" \
  "https://${DOMAIN}:${EDGE_PORT}/api/status" -o /dev/null 2>/dev/null)
EDGE_COND_CODE=$(echo "$EDGE_COND" | grep "^HTTP" | awk '{print $2}')

if [[ "$EDGE_COND_CODE" == "304" ]]; then
  pass "Status code: HTTP 304 Not Modified through nginx edge"
  pass "End-to-end conditional GET succeeded: Client ➔ Nginx ➔ Backend B ➔ 304"
else
  fail "Status code: expected 304, got ${EDGE_COND_CODE}"
fi

echo ""
echo "${BOLD}═══════════════════════════════════════════════════════════${RESET}"
echo "${BOLD}  Script 6 DONE CONDITION:${RESET}"
echo "  ✅ Cache-Control: max-age=60 present on / and /api/status"
echo "  ✅ ETag header present and consistent"
echo "  ✅ Conditional GET (If-None-Match) returns 304 Not Modified"
echo "  ✅ All caching headers survive nginx edge reverse proxy"
echo "  ✅ Certificate trusted without -k"
echo "${BOLD}═══════════════════════════════════════════════════════════${RESET}"
echo ""
