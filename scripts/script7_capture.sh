#!/usr/bin/env zsh
# =============================================================================
# Script 7 — Evidence Capture Helper
# Project: CN_Project | Machine: Mac 2 (Aditya) — 10.7.17.151
# Domain:  https://app.team1.test
# =============================================================================
# WHAT THIS DOES:
#   1. Flushes DNS cache so a fresh DNS query is forced (visible in Wireshark)
#   2. Runs curl against https://app.team1.test to capture full HTTP headers
#   3. Repeats 8 times to demonstrate round-robin load balancing (A/B/A/B...)
#   4. Saves all output to evidence/script7/curl_output/
#
# PREREQUISITES:
#   - Wireshark capture already running on en0 (start it BEFORE this script)
#   - DNS resolves app.team1.test → 10.7.17.151  (Mac 1 dnsmasq)
#   - nginx serving HTTPS on 443 with self-signed cert in configs/tls/
#   - Backend A (10.7.16.201:3001) and Backend B (10.7.16.36:3002) are up
#
# RUN:
#   chmod +x scripts/script7_capture.sh
#   ./scripts/script7_capture.sh
# =============================================================================

set -euo pipefail

OUTDIR="evidence/script7/curl_output"
DOMAIN="app.team1.test"
URL="https://${DOMAIN}:8443"
CERT="configs/tls/team1.test.crt"
DNS_SERVER="10.7.15.236"   # Mac 1 — dnsmasq
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# ---------------------------------------------------------------------------
# 0. Sanity checks
# ---------------------------------------------------------------------------
echo "=== Script 7 — Evidence Capture ==="
echo "Timestamp : ${TIMESTAMP}"
echo "Target    : ${URL}"
echo "Cert      : ${CERT}"
echo "DNS       : ${DNS_SERVER}"
echo ""

if [[ ! -f "${CERT}" ]]; then
  echo "ERROR: Certificate not found at ${CERT}"
  echo "Expected: configs/tls/team1.test.crt"
  exit 1
fi

# ---------------------------------------------------------------------------
# 1. Flush DNS cache — forces a real DNS query (visible in Wireshark)
# ---------------------------------------------------------------------------
echo "--- [1/4] Flushing DNS cache ---"
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder 2>/dev/null || true
echo "DNS cache flushed. Wireshark should now capture a DNS query for ${DOMAIN}."
echo ""
sleep 1

# ---------------------------------------------------------------------------
# 2. Single verbose request — full TLS + header detail
# ---------------------------------------------------------------------------
echo "--- [2/4] Single verbose request (full TLS detail) ---"
VERBOSE_OUT="${OUTDIR}/verbose_single_${TIMESTAMP}.txt"

curl -v \
  --cacert "${CERT}" \
  --resolve "${DOMAIN}:8443:10.7.17.151" \
  "${URL}/api/status" \
  2>&1 | tee "${VERBOSE_OUT}"

echo ""
echo "Saved: ${VERBOSE_OUT}"
echo ""

# ---------------------------------------------------------------------------
# 3. Header-only requests x8 — demonstrate round-robin (A then B alternating)
# ---------------------------------------------------------------------------
echo "--- [3/4] Round-robin demonstration (8 requests) ---"
RR_OUT="${OUTDIR}/roundrobin_${TIMESTAMP}.txt"

echo "Request# | X-Backend | HTTP Status | Timestamp" | tee "${RR_OUT}"
echo "---------|-----------|-------------|----------" | tee -a "${RR_OUT}"

for i in {1..8}; do
  RESPONSE=$(curl -sI \
    --cacert "${CERT}" \
    --resolve "${DOMAIN}:8443:10.7.17.151" \
    "${URL}/api/status" 2>&1)

  BACKEND=$(echo "${RESPONSE}" | grep -i "x-backend:" | tr -d '\r' | awk '{print $2}')
  STATUS=$(echo "${RESPONSE}"  | grep "HTTP/" | awk '{print $2}')
  TS=$(date +"%H:%M:%S")

  printf "%-9s| %-10s| %-12s| %s\n" "${i}" "${BACKEND}" "${STATUS}" "${TS}" | tee -a "${RR_OUT}"
  sleep 0.3
done

echo ""
echo "Saved: ${RR_OUT}"
echo ""

# ---------------------------------------------------------------------------
# 4. Direct backend health checks (bypass nginx — for comparison)
# ---------------------------------------------------------------------------
echo "--- [4/4] Direct backend health checks (no TLS, direct IP) ---"
DIRECT_OUT="${OUTDIR}/direct_backends_${TIMESTAMP}.txt"

echo "=== Backend A direct ===" | tee "${DIRECT_OUT}"
curl -sv http://10.7.16.201:3001/api/status 2>&1 | tee -a "${DIRECT_OUT}" || \
  echo "Backend A unreachable" | tee -a "${DIRECT_OUT}"

echo "" | tee -a "${DIRECT_OUT}"
echo "=== Backend B direct ===" | tee -a "${DIRECT_OUT}"
curl -sv http://10.7.16.36:3002/api/status 2>&1 | tee -a "${DIRECT_OUT}" || \
  echo "Backend B unreachable" | tee -a "${DIRECT_OUT}"

echo ""
echo "Saved: ${DIRECT_OUT}"
echo ""

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
echo "============================================"
echo "All curl evidence saved to: ${OUTDIR}/"
echo ""
echo "NEXT STEPS:"
echo "  1. Stop Wireshark capture"
echo "  2. Save .pcapng to: evidence/script7/pcap/script7_${TIMESTAMP}.pcapng"
echo "  3. Take annotated screenshots → evidence/script7/screenshots/"
echo "  4. Fill in docs/script7_completion_report.md with packet numbers"
echo "============================================"
