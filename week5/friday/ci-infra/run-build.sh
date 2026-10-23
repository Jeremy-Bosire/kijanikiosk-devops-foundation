#!/usr/bin/env bash
# Triggers the kijanikiosk-payments job, waits for it, and saves the console log.
#   ./run-build.sh [log-file]
set -euo pipefail

JENKINS="${JENKINS:-http://localhost:8080}"
JOB="kijanikiosk-payments"
pw_file="${HOME}/.kijanikiosk-ci/jenkins_admin_password"
jar="$(mktemp)"; trap 'rm -f "$jar"' EXIT
auth=(-u "admin:$(cat "$pw_file")" -b "$jar" -c "$jar")

crumb="$(curl -fsS "${auth[@]}" "$JENKINS/crumbIssuer/api/json" \
  | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d["crumbRequestField"]+":"+d["crumb"])')"

next="$(curl -fsS "${auth[@]}" "$JENKINS/job/$JOB/api/json?tree=nextBuildNumber" \
  | python3 -c 'import json,sys; print(json.load(sys.stdin)["nextBuildNumber"])')"
curl -fsS "${auth[@]}" -H "$crumb" -X POST "$JENKINS/job/$JOB/build" -o /dev/null
echo "Triggered $JOB #$next"

until result="$(curl -fsS "${auth[@]}" "$JENKINS/job/$JOB/$next/api/json?tree=building,result,duration" 2>/dev/null \
  | python3 -c 'import json,sys; d=json.load(sys.stdin); print("" if d["building"] else "%s %ds" % (d["result"], d["duration"] // 1000))' 2>/dev/null)" \
  && [[ -n "$result" ]]; do
  sleep 5
done
echo "#$next finished: $result"

if [[ -n "${1:-}" ]]; then
  curl -fsS "${auth[@]}" "$JENKINS/job/$JOB/$next/consoleText" -o "$1"
  echo "Console log saved to $1"
fi
