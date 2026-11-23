#!/usr/bin/env bash
# CN Project — Extension C: Backend B Service Isolation
# pf_rollback.sh — removes the Backend B isolation anchor and restores prior pf state
#
# USAGE: sudo bash pf_rollback.sh

set -euo pipefail

ANCHOR_NAME="com.cn-project.backend-b-isolation"
ANCHOR_FILE="/etc/pf.anchors/${ANCHOR_NAME}"
PF_CONF="/etc/pf.conf"
BACKUP_CONF="/etc/pf.conf.bak-cn-extension-c"

if [ "$(id -u)" -ne 0 ]; then
  echo "ERROR: This script must be run as root (sudo)." >&2
  exit 1
fi

# ── Flush the anchor rules (removes enforcement immediately) ───────────────
echo "[rollback] Flushing anchor rules: ${ANCHOR_NAME}"
pfctl -a "${ANCHOR_NAME}" -F rules 2>/dev/null && echo "[rollback] Anchor rules flushed." || echo "[rollback] Anchor was not loaded (nothing to flush)."

# ── Remove the anchor rules file ───────────────────────────────────────────
if [ -f "${ANCHOR_FILE}" ]; then
  echo "[rollback] Removing anchor file: ${ANCHOR_FILE}"
  rm "${ANCHOR_FILE}"
else
  echo "[rollback] Anchor file not found — already removed."
fi

# ── Restore /etc/pf.conf from backup ───────────────────────────────────────
if [ -f "${BACKUP_CONF}" ]; then
  echo "[rollback] Restoring ${PF_CONF} from backup ${BACKUP_CONF}"
  cp "${BACKUP_CONF}" "${PF_CONF}"
  echo "[rollback] Reloading pf with restored config..."
  pfctl -f "${PF_CONF}"
  echo "[rollback] pf reloaded from original config."
else
  echo "[rollback] WARNING: No backup found at ${BACKUP_CONF}."
  echo "[rollback] Manually remove the anchor lines from ${PF_CONF} and run: sudo pfctl -f ${PF_CONF}"
fi

echo
echo "[rollback] Rollback complete. Port 3002 is now unrestricted (back to pre-Extension-C state)."
