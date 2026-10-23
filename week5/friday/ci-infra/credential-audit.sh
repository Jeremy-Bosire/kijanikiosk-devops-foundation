#!/usr/bin/env bash
# Five credential checks against the final Jenkinsfile, the git history and every Jenkins
# build log. Searches for the ACTUAL secret values (and their base64 forms) without printing them.
set -uo pipefail
cd "$(git rev-parse --show-toplevel)"
S="${HOME}/.kijanikiosk-ci"
JP=$(cat "$S/jenkins_admin_password")
secrets=("$(cat "$S/nexus_publisher_password")" "$(cat "$S/nexus_admin_password")" "$JP"
         "$(printf 'kk-publisher:%s' "$(cat "$S/nexus_publisher_password")" | base64 | tr -d '\n')")
labels=("nexus publisher password" "nexus admin password" "jenkins admin password" "base64 publisher _auth string")
pattern='(password|passwd|secret|token|_auth|apikey)[[:space:]]*[:=][[:space:]]*["'"'"']?[A-Za-z0-9+/=]{8,}'
fail=0
result() { if [[ "$2" -eq 0 ]]; then echo "  PASS  $1"; else echo "  FAIL  $1 ($2 matches)"; fail=1; fi; }
count_values() { local c=0; for s in "${secrets[@]}"; do c=$((c + $(grep -cF -- "$s" <<<"$1" || true))); done; echo "$c"; }

echo "Credential audit: $(date -u +%FT%TZ)"
echo "Branch $(git branch --show-current) @ $(git rev-parse --short HEAD); Jenkinsfile blob $(git rev-parse --short HEAD:Jenkinsfile)"
echo

echo "[1] Jenkinsfile: no literal secret values or credential assignments"
result "secret values in Jenkinsfile" "$(count_values "$(cat Jenkinsfile)")"
result "credential-like assignments in Jenkinsfile" "$(grep -ciE "$pattern" Jenkinsfile || true)"
echo "  INFO  credentials referenced by ID only: $(grep -oE "credentialsId: env.NEXUS_CREDENTIALS_ID|NEXUS_CREDENTIALS_ID = '[^']+'" Jenkinsfile | tr '\n' ' ')"
echo "  INFO  secrets only in single-quoted sh (no Groovy interpolation): $(grep -c "sh '''" Jenkinsfile) single-quoted blocks, $(grep -cE 'sh """.*NEXUS_PASS' Jenkinsfile) double-quoted blocks using NEXUS_PASS"

echo "[2] Git history: every commit on this branch since week 5 started ($(git rev-list --count origin/develop..HEAD) commits)"
hist="$(git log -p origin/develop..HEAD)"
for i in "${!secrets[@]}"; do result "${labels[$i]} in any commit diff" "$(grep -cF -- "${secrets[$i]}" <<<"$hist" || true)"; done
result "credential-like assignments added in any diff" "$(grep -E '^\+' <<<"$hist" | grep -ciE "$pattern" || true)"

echo "[3] Build logs: every run of kijanikiosk-payments"
last=$(curl -fs -u "admin:$JP" "http://localhost:8080/job/kijanikiosk-payments/api/json?tree=lastBuild%5Bnumber%5D" | python3 -c 'import json,sys; print(json.load(sys.stdin)["lastBuild"]["number"])')
logs=""; for n in $(seq 1 "$last"); do logs+="$(curl -fs -u "admin:$JP" "http://localhost:8080/job/kijanikiosk-payments/$n/consoleText")"$'\n'; done
echo "  INFO  scanned builds #1-#$last ($(wc -l <<<"$logs") lines)"
for i in "${!secrets[@]}"; do result "${labels[$i]} in any build log" "$(grep -cF -- "${secrets[$i]}" <<<"$logs" || true)"; done
echo "  INFO  'Masking supported pattern matches' lines: $(grep -c 'Masking supported pattern matches' <<<"$logs")"
result "Groovy string interpolation warnings for secrets" "$(grep -c 'insecure' <<<"$logs" || true)"

echo "[4] .npmrc: never committed, never left behind"
result ".npmrc in any commit" "$(git log --all --name-only --format= | grep -c '\.npmrc$' || true)"
result ".npmrc in Jenkins workspace or JENKINS_HOME" "$(docker exec kk-jenkins find /var/jenkins_home -name .npmrc 2>/dev/null | wc -l)"
echo "  INFO  .npmrc gitignored: $(git check-ignore -q kijanikiosk-payments/.npmrc && echo yes || echo no)"

echo "[5] Working tree and infrastructure-as-code: no secret values in any tracked file"
tracked="$(git ls-files -z | xargs -0 cat 2>/dev/null | tr -d '\0')"
for i in "${!secrets[@]}"; do result "${labels[$i]} in tracked files" "$(grep -cF -- "${secrets[$i]}" <<<"$tracked" || true)"; done
echo "  INFO  secrets live only in ~/.kijanikiosk-ci (mode $(stat -c %a "$S")), mounted as Docker secrets"

echo
[[ $fail -eq 0 ]] && echo "RESULT: PASS: 0 credential matches across Jenkinsfile, git history and build logs" || echo "RESULT: FAIL"
exit $fail
