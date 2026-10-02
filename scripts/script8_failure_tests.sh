#!/bin/bash
# Helper script for SCRIPT 8: Phase 1 Failure Tests

DOMAIN="app.team1.test"
DNS_SERVER="10.7.15.236"
EDGE_IP="10.7.17.151"
PORT="8443"

echo "=========================================================="
echo "    SCRIPT 8 Helper - Phase 1 Failure Tests"
echo "=========================================================="
echo "This script runs the commands for the failure tests."
echo "Follow the prompts to perform each test."
echo "=========================================================="
echo ""

# TEST 1: Wrong DNS Server
echo "----------------------------------------------------------"
echo "TEST 1: Wrong DNS Server (Querying 8.8.8.8 instead of our DNS)"
echo "----------------------------------------------------------"
echo "Command: dig $DOMAIN @8.8.8.8 +short"
dig $DOMAIN @8.8.8.8 +short
echo "(If nothing printed above, the query failed as expected!)"
echo ""
read -p "Press Enter to continue to Test 2..."

# TEST 2: Wrong DNS Record (Simulated)
echo "----------------------------------------------------------"
echo "TEST 2: Wrong DNS Record (Connecting to fake IP 10.7.17.99)"
echo "----------------------------------------------------------"
echo "Command: curl -s -v -k --connect-timeout 3 --resolve $DOMAIN:$PORT:10.7.17.99 https://$DOMAIN:$PORT/api/status"
curl -s -v -k --connect-timeout 3 --resolve $DOMAIN:$PORT:10.7.17.99 https://$DOMAIN:$PORT/api/status
echo ""
read -p "Press Enter to continue to Test 3..."

# TEST 3: Stop Backend A
echo "----------------------------------------------------------"
echo "TEST 3: Stop Backend A"
echo "----------------------------------------------------------"
echo "*** ACTION REQUIRED: Ask Mac 3 to STOP Backend A now. ***"
read -p "Press Enter when Mac 3 says it is stopped..."
echo "Command: curl -s -k --resolve $DOMAIN:$PORT:$EDGE_IP https://$DOMAIN:$PORT/api/status"
for i in {1..4}; do
    curl -s -k --resolve $DOMAIN:$PORT:$EDGE_IP https://$DOMAIN:$PORT/api/status
    echo ""
    sleep 1
done
echo "*** ACTION REQUIRED: Ask Mac 3 to START Backend A again. ***"
read -p "Press Enter when Mac 3 says it is running..."

# TEST 4: Stop Backend B
echo "----------------------------------------------------------"
echo "TEST 4: Stop Backend B"
echo "----------------------------------------------------------"
echo "*** ACTION REQUIRED: Ask Mac 4 to STOP Backend B now. ***"
read -p "Press Enter when Mac 4 says it is stopped..."
echo "Command: curl -s -k --resolve $DOMAIN:$PORT:$EDGE_IP https://$DOMAIN:$PORT/api/status"
for i in {1..4}; do
    curl -s -k --resolve $DOMAIN:$PORT:$EDGE_IP https://$DOMAIN:$PORT/api/status
    echo ""
    sleep 1
done
echo "*** ACTION REQUIRED: Ask Mac 4 to START Backend B again. ***"
read -p "Press Enter when Mac 4 says it is running..."

# TEST 5: Stop Both Backends
echo "----------------------------------------------------------"
echo "TEST 5: Stop Both Backends"
echo "----------------------------------------------------------"
echo "*** ACTION REQUIRED: Ask Mac 3 and Mac 4 to STOP both backends now. ***"
read -p "Press Enter when both are stopped..."
echo "Command: curl -s -i -k --resolve $DOMAIN:$PORT:$EDGE_IP https://$DOMAIN:$PORT/api/status"
curl -s -i -k --resolve $DOMAIN:$PORT:$EDGE_IP https://$DOMAIN:$PORT/api/status
echo ""
echo "*** ACTION REQUIRED: Ask Mac 3 and Mac 4 to START both backends again. ***"
read -p "Press Enter when both are running..."

# TEST 6: Wrong Destination Port
echo "----------------------------------------------------------"
echo "TEST 6: Wrong Destination Port (Trying port 9999)"
echo "----------------------------------------------------------"
echo "Command: curl -s -v -k --resolve $DOMAIN:9999:$EDGE_IP https://$DOMAIN:9999/api/status"
curl -s -v -k --resolve $DOMAIN:9999:$EDGE_IP https://$DOMAIN:9999/api/status
echo ""

echo "=========================================================="
echo "All tests complete! Fill out docs/script8_completion_report.md"
echo "=========================================================="
