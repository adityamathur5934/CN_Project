#!/usr/bin/env bash
# Quick verification script for Backend B (Mac 4)
LAN_IP=$(ipconfig getifaddr en0 2>/dev/null || echo "10.7.2.96")

echo "============================================="
echo " 1. Testing GET / on localhost (127.0.0.1:3002)"
echo "============================================="
curl -si http://127.0.0.1:3002/
echo ""

echo "============================================="
echo " 2. Testing GET /api/status on localhost"
echo "============================================="
curl -si http://127.0.0.1:3002/api/status
echo ""

echo "============================================="
echo " 3. Testing GET /api/status on LAN IP ($LAN_IP:3002)"
echo "============================================="
curl -si "http://$LAN_IP:3002/api/status"
echo ""

echo "============================================="
echo " 4. Testing Conditional GET (If-None-Match: \"backend-b-v1\")"
echo "============================================="
curl -si -H 'If-None-Match: "backend-b-v1"' "http://$LAN_IP:3002/api/status"
echo ""
