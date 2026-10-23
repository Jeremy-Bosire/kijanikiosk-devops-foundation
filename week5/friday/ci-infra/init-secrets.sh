#!/usr/bin/env bash
# Generates the CI passwords into ~/.kijanikiosk-ci (outside the repo, mode 600).
# Existing files are kept, so re-running is safe.
set -euo pipefail

dir="${HOME}/.kijanikiosk-ci"
mkdir -p "$dir"
chmod 700 "$dir"

for name in jenkins_admin_password nexus_admin_password nexus_publisher_password; do
  if [[ ! -s "$dir/$name" ]]; then
    # Alphanumeric only: no characters that need escaping in YAML, shell or URLs.
    # (`|| true`: head closing the pipe early makes tr exit with SIGPIPE under pipefail)
    pw="$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 24 || true)"
    printf '%s' "$pw" >"$dir/$name"
    echo "created $dir/$name"
  else
    echo "kept    $dir/$name"
  fi
  chmod 600 "$dir/$name"
done
