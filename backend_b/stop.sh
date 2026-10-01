#!/usr/bin/env bash
# Stop Backend B
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PID_FILE="$DIR/backend_b.pid"

if [ -f "$PID_FILE" ]; then
    PID="$(cat "$PID_FILE")"
    if kill -0 "$PID" 2>/dev/null; then
        echo "[Backend B] Stopping process (PID: $PID)..."
        kill "$PID"
        rm -f "$PID_FILE"
        echo "[Backend B] Stopped."
        exit 0
    else
        echo "[Backend B] Stale PID file found. Removing..."
        rm -f "$PID_FILE"
    fi
fi

# Fallback: check if any process is bound to port 3002
OCCUPIED_PID="$(lsof -ti :3002)"
if [ -n "$OCCUPIED_PID" ]; then
    echo "[Backend B] Killing process on port 3002 (PID: $OCCUPIED_PID)..."
    kill "$OCCUPIED_PID"
    echo "[Backend B] Port 3002 freed."
else
    echo "[Backend B] Not running."
fi
