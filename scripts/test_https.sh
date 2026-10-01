#!/usr/bin/env zsh
# =============================================================================
# test_https.sh — Script 5: Full HTTPS verification
# Mac 2 (P2 — Aditya) | Run after cert trust is installed on the client
# Usage: ./scripts/test_https.sh
# =============================================================================

DOMAIN="app.team1.test"
HTTPS_PORT="8443"
HTTP_PORT="8080"
EDGE_IP="10.7.17.151"
CERT="/Users/aditya.2024/Documents/Projects/CN_Project/configs/tls/team1.test.crt"
REQUESTS=8

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; BOLD='\033[1m'; RESET='\033[0m'
pass() { echo "${GREEN}  ✅ PASS${RESET} — $1"; }
fail() { echo "${RED}  ❌ FAIL${RESET} — $1"; }
warn() { echo "${YELLOW}  ⚠${RESET}  $1"; }

echo ""
echo "${BOLD}═══════════════════════════════════════════════════════════${RESET}"
echo "${BOLD}  Script 5 — HTTPS / TLS Verification  |  Mac 2 (P2)${RESET}"
echo "${BOLD}  Domain: https://${DOMAIN}:${HTTPS_PORT}${RESET}"
echo "${BOLD}═══════════════════════════════════════════════════════════${RESET}"
echo ""

# ── 1. DNS resolution ────────────────────────────────────────────────────────
echo "${BOLD}[1/5] DNS resolution${RESET}"
RESOLVED=$(dig +short "$DOMAIN" 2>/dev/null | head -1)
if [[ "$RESOLVED" == "$EDGE_IP" ]]; then
  pass "${DOMAIN} → ${RESOLVED}"
else
  fail "${DOMAIN} → '${RESOLVED}' (expected ${EDGE_IP})"
  warn "Check DNS: dig ${DOMAIN} @10.7.15.236"
fi
echo ""

# ── 2. TLS handshake — no -k ─────────────────────────────────────────────────
echo "${BOLD}[2/5] HTTPS without -k (certificate must be trusted)${RESET}"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 \
  "https://${DOMAIN}:${HTTPS_PORT}/health" 2>/dev/null)
if [[ "$HTTP_CODE" == "200" ]]; then
  pass "curl https://${DOMAIN}:${HTTPS_PORT}/health — HTTP $HTTP_CODE (no -k)"
else
  fail "HTTP $HTTP_CODE — certificate may not be trusted on this machine"
  warn "Install trust: sudo security add-trusted-cert -d -r trustRoot \\"
  warn "  -k /Library/Keychains/System.keychain \\"
  warn "  ${CERT}"
fi
echo ""

# ── 3. TLS protocol and cipher ───────────────────────────────────────────────
echo "${BOLD}[3/5] TLS protocol and cipher${RESET}"
TLS_INFO=$(echo | openssl s_client -connect "${DOMAIN}:${HTTPS_PORT}" \
  -servername "$DOMAIN" 2>/dev/null | grep -E "Protocol|Cipher")
PROTOCOL=$(echo "$TLS_INFO" | grep "Protocol" | awk '{print $NF}')
CIPHER=$(echo "$TLS_INFO" | grep "Cipher" | awk '{print $NF}')
if [[ "$PROTOCOL" == TLSv* ]]; then
  pass "Protocol: ${PROTOCOL}"
  pass "Cipher:   ${CIPHER}"
else
  fail "Could not determine TLS protocol"
fi
echo ""

# ── 4. HTTP → HTTPS redirect ─────────────────────────────────────────────────
echo "${BOLD}[4/5] HTTP → HTTPS redirect (port ${HTTP_PORT})${RESET}"
REDIRECT=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 \
  "http://${DOMAIN}:${HTTP_PORT}/api/status" 2>/dev/null)
LOCATION=$(curl -s -D - -o /dev/null --connect-timeout 5 \
  "http://${DOMAIN}:${HTTP_PORT}/api/status" 2>/dev/null | grep -i "^Location" | tr -d '\r')
if [[ "$REDIRECT" == "301" ]]; then
  pass "HTTP ${HTTP_PORT} → 301 Moved Permanently"
  pass "Location: ${LOCATION#Location: }"
else
  fail "Expected 301, got $REDIRECT"
fi
echo ""

# ── 5. Load balancer over HTTPS ──────────────────────────────────────────────
echo "${BOLD}[5/5] Round-robin load balancer over HTTPS (${REQUESTS} requests)${RESET}"
COUNT_A=0; COUNT_B=0; COUNT_ERR=0

for i in $(seq 1 $REQUESTS); do
  RESULT=$(curl -s -D - --connect-timeout 5 \
    "https://${DOMAIN}:${HTTPS_PORT}/api/status" 2>/dev/null)
  CODE=$(echo "$RESULT" | grep "^HTTP" | awk '{print $2}')
  XBACKEND=$(echo "$RESULT" | grep -i "x-backend" | tr -d '\r' | awk '{print $2}')
  BODY=$(echo "$RESULT" | tail -1)

  echo "  Request $(printf '%2d' $i) → HTTP ${CODE} | X-Backend: ${XBACKEND} | ${BODY}"
  [[ "$XBACKEND" == "A" ]] && (( COUNT_A++ ))
  [[ "$XBACKEND" == "B" ]] && (( COUNT_B++ ))
  [[ "$CODE" != "200" ]] && (( COUNT_ERR++ ))
done

echo ""
echo "  Backend A: ${COUNT_A} requests | Backend B: ${COUNT_B} requests | Errors: ${COUNT_ERR}"
echo ""

if (( COUNT_A > 0 && COUNT_B > 0 && COUNT_ERR == 0 )); then
  pass "Both backends served traffic over HTTPS ✅"
else
  fail "One or both backends not reached over HTTPS"
fi

echo ""
echo "${BOLD}═══════════════════════════════════════════════════════════${RESET}"
echo "${BOLD}  Script 5 DONE CONDITION:${RESET}"
echo "  ✅ HTTPS works with proper certificate validation (no -k)"
echo "  ✅ TLS terminates at nginx (backends stay plain HTTP)"
echo "  ✅ Both X-Backend: A and X-Backend: B visible over HTTPS"
echo "  ✅ HTTP redirects to HTTPS"
echo "${BOLD}  Next step: Script 7 — Wireshark evidence capture${RESET}"
echo "${BOLD}═══════════════════════════════════════════════════════════${RESET}"
echo ""
