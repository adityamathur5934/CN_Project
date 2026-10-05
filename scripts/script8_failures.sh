#!/usr/bin/env zsh
# =============================================================================
# Script 8 — Phase 1 Failure Tests (Automated: Tests 3, 4, 5)
# Project: CN_Project | Machine: Mac 2 (Aditya) — 10.7.17.151
#
# Tests covered here (run from Mac 2, no coordination needed):
#   Test 3 — Stop Backend A  → nginx should serve B only
#   Test 4 — Stop Backend B  → nginx should serve A only
#   Test 5 — Stop both       → nginx should return 502 Bad Gateway
#
# Tests NOT covered here (manual, see script8_manual_tests.md):
#   Test 1 — Wrong DNS server   (done on Mac 4 / Mac 1)
#   Test 2 — Wrong DNS record   (done on Mac 1 dnsmasq)
#   Test 6 — Wrong port         (done via curl flag)
#
# SAFETY:
#   - Backends are stopped/started via their own stop.sh/start.sh scripts
#   - nginx is never touched — it stays running throughout
#   - Every test restores the backend before moving on
#   - set -e is intentionally OFF so failures are captured, not aborted
# =============================================================================

OUTDIR="evidence/script8"
CERT="configs/tls/team1.test.crt"
DOMAIN="app.team1.test"
URL="https://${DOMAIN}:8443/api/status"
RESOLVE="--resolve ${DOMAIN}:8443:10.7.17.151"
BACKEND_A_HOST="10.7.16.201"
BACKEND_B_HOST="10.7.2.96"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Helper — run 4 curl requests and print X-Backend or error
probe() {
  local label="$1"
  echo "  Probing ($label) — 4 requests:"
  for i in {1..4}; do
    RESULT=$(curl -s --max-time 5 --cacert "${CERT}" ${RESOLVE} "${URL}" 2>&1)
    CODE=$(curl -so /dev/null -w "%{http_code}" --max-time 5 --cacert "${CERT}" ${RESOLVE} "${URL}" 2>/dev/null)
    BACKEND=$(echo "$RESULT" | grep -o '"[AB]"' | tr -d '"')
    if [[ -z "$BACKEND" ]]; then
      echo "    Request $i → HTTP $CODE | Response: $RESULT"
    else
      echo "    Request $i → HTTP $CODE | X-Backend: $BACKEND"
    fi
    sleep 0.3
  done
}

# Helper — check if a backend is reachable directly
check_backend() {
  local ip="$1" port="$2" name="$3"
  RESULT=$(curl -so /dev/null -w "%{http_code}" --max-time 3 http://${ip}:${port}/api/status 2>/dev/null)
  echo "  Direct check ${name} (${ip}:${port}) → HTTP $RESULT"
}

echo "============================================"
echo "Script 8 — Phase 1 Failure Tests"
echo "Timestamp: ${TIMESTAMP}"
echo "============================================"
echo ""

# ---------------------------------------------------------------------------
# BASELINE — confirm system is healthy before any tests
# ---------------------------------------------------------------------------
echo "=== BASELINE: System Health Check ==="
check_backend $BACKEND_A_HOST 3001 "Backend A"
check_backend $BACKEND_B_HOST 3002 "Backend B"
probe "baseline"
echo ""
echo "Baseline saved. Starting tests."
echo ""

# ---------------------------------------------------------------------------
# TEST 3 — Stop Backend A
# ---------------------------------------------------------------------------
echo "============================================"
echo "TEST 3 — Stop Backend A (Mac 3 / 10.7.16.201:3001)"
echo "============================================"
T3_OUT="${OUTDIR}/test3_stop_backend_a/test3_${TIMESTAMP}.txt"

{
  echo "TEST 3 — Stop Backend A"
  echo "Timestamp: $(date)"
  echo "Expected: All requests route to Backend B only (no A)"
  echo "---"

  echo "[INITIAL STATE]"
  check_backend $BACKEND_A_HOST 3001 "Backend A"
  check_backend $BACKEND_B_HOST 3002 "Backend B"
  probe "before fault"

  echo ""
  echo "[FAULT INJECTION]"
  echo "  Action: Ask Mac 3 (Krishiv) to stop Backend A"
  echo "  Command to run on Mac 3: cd backend_a && python3 server.py stop  (or kill the process)"
  echo ""
  echo "  *** PAUSE: Tell Krishiv to stop Backend A, then press ENTER to continue ***"
  read -r

  echo "[FAULT ACTIVE — Testing]"
  check_backend $BACKEND_A_HOST 3001 "Backend A"
  probe "fault active"

  echo ""
  echo "[RESTORE]"
  echo "  Action: Ask Mac 3 (Krishiv) to restart Backend A"
  echo "  *** PAUSE: Tell Krishiv to start Backend A, then press ENTER to continue ***"
  read -r

  echo "[POST-RESTORE]"
  check_backend $BACKEND_A_HOST 3001 "Backend A"
  probe "after restore"

} 2>&1 | tee "${T3_OUT}"

echo "Test 3 saved: ${T3_OUT}"
echo ""

# ---------------------------------------------------------------------------
# TEST 4 — Stop Backend B
# ---------------------------------------------------------------------------
echo "============================================"
echo "TEST 4 — Stop Backend B (Mac 4 / 10.7.2.96:3002)"
echo "============================================"
T4_OUT="${OUTDIR}/test4_stop_backend_b/test4_${TIMESTAMP}.txt"

{
  echo "TEST 4 — Stop Backend B"
  echo "Timestamp: $(date)"
  echo "Expected: All requests route to Backend A only (no B)"
  echo "---"

  echo "[INITIAL STATE]"
  check_backend $BACKEND_A_HOST 3001 "Backend A"
  check_backend $BACKEND_B_HOST 3002 "Backend B"
  probe "before fault"

  echo ""
  echo "[FAULT INJECTION]"
  echo "  Action: Ask Mac 4 (Vaidehi) to stop Backend B"
  echo "  *** PAUSE: Tell Vaidehi to stop Backend B, then press ENTER to continue ***"
  read -r

  echo "[FAULT ACTIVE — Testing]"
  check_backend $BACKEND_B_HOST 3002 "Backend B"
  probe "fault active"

  echo ""
  echo "[RESTORE]"
  echo "  *** PAUSE: Tell Vaidehi to start Backend B, then press ENTER to continue ***"
  read -r

  echo "[POST-RESTORE]"
  check_backend $BACKEND_B_HOST 3002 "Backend B"
  probe "after restore"

} 2>&1 | tee "${T4_OUT}"

echo "Test 4 saved: ${T4_OUT}"
echo ""

# ---------------------------------------------------------------------------
# TEST 5 — Stop both backends
# ---------------------------------------------------------------------------
echo "============================================"
echo "TEST 5 — Stop Both Backends"
echo "============================================"
T5_OUT="${OUTDIR}/test5_stop_both/test5_${TIMESTAMP}.txt"

{
  echo "TEST 5 — Stop Both Backends"
  echo "Timestamp: $(date)"
  echo "Expected: nginx returns 502 Bad Gateway (no upstream available)"
  echo "---"

  echo "[INITIAL STATE]"
  check_backend $BACKEND_A_HOST 3001 "Backend A"
  check_backend $BACKEND_B_HOST 3002 "Backend B"
  probe "before fault"

  echo ""
  echo "[FAULT INJECTION]"
  echo "  Action: Ask BOTH Krishiv and Vaidehi to stop their backends"
  echo "  *** PAUSE: Tell both to stop, then press ENTER to continue ***"
  read -r

  echo "[FAULT ACTIVE — Testing]"
  check_backend $BACKEND_A_HOST 3001 "Backend A"
  check_backend $BACKEND_B_HOST 3002 "Backend B"
  probe "fault active"

  echo ""
  echo "[RESTORE]"
  echo "  *** PAUSE: Tell both to start their backends, then press ENTER to continue ***"
  read -r

  echo "[POST-RESTORE]"
  check_backend $BACKEND_A_HOST 3001 "Backend A"
  check_backend $BACKEND_B_HOST 3002 "Backend B"
  probe "after restore"

} 2>&1 | tee "${T5_OUT}"

echo "Test 5 saved: ${T5_OUT}"
echo ""

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
echo "============================================"
echo "Tests 3, 4, 5 complete."
echo "Evidence saved to: ${OUTDIR}/"
echo ""
echo "Still to do manually:"
echo "  Test 1 — Wrong DNS server  (see scripts/script8_manual_tests.md)"
echo "  Test 2 — Wrong DNS record  (see scripts/script8_manual_tests.md)"
echo "  Test 6 — Wrong port        (see scripts/script8_manual_tests.md)"
echo "============================================"
