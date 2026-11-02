#!/usr/bin/env bash
set -euo pipefail

CONFIDENCE_SECONDS=${1:-60}
PROXY_URL=${PROXY_URL:-http://127.0.0.1:80/health}
POLL_INTERVAL=5
FAILURES=0

failures_needed=$(( (CONFIDENCE_SECONDS + 5) / 5 ))
echo "[$(date -u +%H:%M:%S)] MONITOR START confidence_window=${CONFIDENCE_SECONDS}s poll_interval=${POLL_INTERVAL}s"

while true; do
  response=$(curl -fsS "$PROXY_URL" 2>/dev/null || true)
  if printf '%s' "$response" | grep -q 'v1.4.0'; then
    FAILURES=0
    echo "[$(date -u +%H:%M:%S)] MONITOR OK v1.4.0"
  else
    FAILURES=$((FAILURES + 1))
    echo "[$(date -u +%H:%M:%S)] MONITOR FAIL count=${FAILURES}/${failures_needed}"
  fi

  if [ "$FAILURES" -ge "$failures_needed" ]; then
    echo "[$(date -u +%H:%M:%S)] [MONITOR FAIL] ROLLBACK TRIGGERED"
    sudo bash /opt/kijanikiosk/scripts/switch-env.sh blue
    break
  fi
  sleep "$POLL_INTERVAL"
done

if curl -fsS "$PROXY_URL" | grep -q 'v1.3.0'; then
  echo "[$(date -u +%H:%M:%S)] T2 rollback confirmed; blue healthy through proxy"
else
  echo "[$(date -u +%H:%M:%S)] ROLLBACK VERIFICATION FAILED" >&2
  exit 1
fi
