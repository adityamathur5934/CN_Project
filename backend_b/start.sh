#!/usr/bin/env bash
# Start Backend B in background
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PID_FILE="$DIR/backend_b.pid"
LOG_FILE="$DIR/backend_b.log"

if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    echo "[Backend B] Already running (PID: $(cat "$PID_FILE"))."
    exit 0
fi

# Check if port 3002 is already occupied
OCCUPIED=$(lsof -ti:3002)
if [ -n "$OCCUPIED" ]; then
    echo "[Backend B] Port 3002 is already in use by PID $OCCUPIED."
    exit 1
fi

nohup python3 "$DIR/server.py" > "$LOG_FILE" 2>&1 &
PID=$!
echo $PID > "$PID_FILE"
echo "[Backend B] Started in background with PID $PID."
echo "[Backend B] Logs: $LOG_FILE"
echo "[Backend B] Verifying local HTTP response..."
sleep 1
curl -s -i http://127.0.0.1:3002/api/status
