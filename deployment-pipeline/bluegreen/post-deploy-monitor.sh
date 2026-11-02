#!/usr/bin/env bash
set -euo pipefail

CONFIDENCE_SECONDS=${1:-60}
PROXY_URL=${PROXY_URL:-http://127.0.0.1:80/health}
POLL_INTERVAL=5
FAILURES=0

if ! [[ "$CONFIDENCE_SECONDS" =~ ^[1-9][0-9]*$ ]]; then
    echo "Usage: $0 [positive-confidence-seconds]"
    exit 1
fi

failures_needed=$(( (CONFIDENCE_SECONDS + POLL_INTERVAL - 1) / POLL_INTERVAL + 1 ))

timestamp() {
    date -u '+%Y-%m-%d %H:%M:%S UTC'
}

echo "[$(timestamp)] MONITOR START confidence_window=${CONFIDENCE_SECONDS}s poll_interval=${POLL_INTERVAL}s"

while true; do
    response=$(curl -fsS --connect-timeout 2 --max-time 4 "$PROXY_URL" 2>/dev/null || true)

    if printf '%s' "$response" | grep -q 'v1.4.0'; then
        FAILURES=0
        echo "[$(timestamp)] MONITOR OK v1.4.0"
    else
        FAILURES=$((FAILURES + 1))
        echo "[$(timestamp)] MONITOR FAIL count=${FAILURES}/${failures_needed}"
    fi

    if [ "$FAILURES" -ge "$failures_needed" ]; then
        echo "[$(timestamp)] [MONITOR FAIL] ROLLBACK TRIGGERED"
        sudo bash /opt/kijanikiosk/scripts/switch-env.sh blue
        break
    fi

    sleep "$POLL_INTERVAL"
done

echo "[$(timestamp)] VERIFYING BLUE THROUGH PROXY"

for attempt in $(seq 1 15); do
    response=$(curl -fsS --connect-timeout 2 --max-time 4 "$PROXY_URL" 2>/dev/null || true)

    if printf '%s' "$response" | grep -q 'v1.3.0'; then
        echo "[$(timestamp)] T2 rollback confirmed; blue healthy through proxy"
        exit 0
    fi

    echo "[$(timestamp)] Waiting for Blue verification (${attempt}/15)"
    sleep 1
done

echo "[$(timestamp)] ROLLBACK VERIFICATION FAILED" >&2
exit 1
