#!/usr/bin/env bash
# One-time Nexus setup through the REST API (safe to re-run):
#   1. accept the Community Edition EULA and rotate the generated admin password
#   2. create the npm-hosted repository with write policy ALLOW_ONCE
#      (a version can be published once and never overwritten)
#   3. create a least-privilege role + kk-publisher user that can only publish to npm-hosted
set -euo pipefail

NEXUS="${NEXUS:-http://localhost:8081}"
REPO="npm-hosted"
SECRETS="${HOME}/.kijanikiosk-ci"
ADMIN_PW="$(cat "$SECRETS/nexus_admin_password")"
PUBLISHER_PW="$(cat "$SECRETS/nexus_publisher_password")"

echo "Waiting for Nexus at $NEXUS ..."
until curl -fs "$NEXUS/service/rest/v1/status/writable" >/dev/null; do sleep 5; done

# Rotate the first-boot admin password if it is still present.
if docker exec kk-nexus test -f /nexus-data/admin.password; then
  initial="$(docker exec kk-nexus cat /nexus-data/admin.password)"
  curl -fs -u "admin:$initial" -X PUT -H 'Content-Type: text/plain' \
    --data "$ADMIN_PW" "$NEXUS/service/rest/v1/security/users/admin/change-password"
  docker exec kk-nexus rm -f /nexus-data/admin.password
  echo "admin password rotated"
fi

api() { curl -fsS -u "admin:$ADMIN_PW" -H 'Content-Type: application/json' "$@"; }

# Community Edition requires the EULA to be accepted before repositories can be used.
# Accepting is a legal decision for the operator, so it is opt-in: NEXUS_ACCEPT_EULA=yes
eula="$(api "$NEXUS/service/rest/v1/system/eula")"
if ! grep -q '"accepted" *: *true' <<<"$eula"; then
  if [[ "${NEXUS_ACCEPT_EULA:-}" != "yes" ]]; then
    echo "$eula"
    echo "Read https://links.sonatype.com/products/nxrm/ce-eula, then re-run with NEXUS_ACCEPT_EULA=yes" >&2
    exit 1
  fi
  python3 -c 'import json,sys; d=json.load(sys.stdin); d["accepted"]=True; print(json.dumps(d))' <<<"$eula" \
    | api -X POST "$NEXUS/service/rest/v1/system/eula" --data @-
  echo "EULA accepted"
fi

api -X PUT "$NEXUS/service/rest/v1/security/anonymous" \
  --data '{"enabled":false,"userId":"anonymous","realmName":"NexusAuthorizingRealm"}' >/dev/null
api -X PUT "$NEXUS/service/rest/v1/security/realms/active" \
  --data '["NexusAuthenticatingRealm","NpmToken"]'

if ! api "$NEXUS/service/rest/v1/repositories/$REPO" >/dev/null 2>&1; then
  api -X POST "$NEXUS/service/rest/v1/repositories/npm/hosted" --data @- <<JSON
{
  "name": "$REPO",
  "online": true,
  "storage": { "blobStoreName": "default", "strictContentTypeValidation": true, "writePolicy": "allow_once" }
}
JSON
  echo "repository $REPO created (writePolicy=allow_once)"
fi

if ! api "$NEXUS/service/rest/v1/security/roles/kk-npm-publisher" >/dev/null 2>&1; then
  api -X POST "$NEXUS/service/rest/v1/security/roles" --data @- >/dev/null <<JSON
{
  "id": "kk-npm-publisher",
  "name": "kk-npm-publisher",
  "description": "Publish and read kijanikiosk packages in $REPO only",
  "privileges": [
    "nx-repository-view-npm-$REPO-add",
    "nx-repository-view-npm-$REPO-edit",
    "nx-repository-view-npm-$REPO-read",
    "nx-repository-view-npm-$REPO-browse"
  ],
  "roles": []
}
JSON
  echo "role kk-npm-publisher created"
fi

if ! api "$NEXUS/service/rest/v1/security/users?userId=kk-publisher" | grep -q '"userId" *: *"kk-publisher"'; then
  api -X POST "$NEXUS/service/rest/v1/security/users" --data @- >/dev/null <<JSON
{
  "userId": "kk-publisher",
  "firstName": "KijaniKiosk",
  "lastName": "CI Publisher",
  "emailAddress": "ci-publisher@kijanikiosk.local",
  "password": "$PUBLISHER_PW",
  "status": "active",
  "roles": ["kk-npm-publisher"]
}
JSON
  echo "user kk-publisher created"
fi

echo "Nexus ready: $NEXUS/repository/$REPO/"
