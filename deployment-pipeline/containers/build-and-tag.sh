#!/usr/bin/env bash
set -euo pipefail

REGISTRY=${REGISTRY:?Set REGISTRY, for example registry.example.com/kijanikiosk}
VERSION=$(node -p "require('./kijanikiosk-payments/package.json').version")
GITSHA=$(git rev-parse --short=7 HEAD)
IMAGE="${REGISTRY}/kk-payments:${VERSION}-${GITSHA}"

docker build --no-cache -f deployment-pipeline/containers/Dockerfile.production -t "$IMAGE" .
echo "$IMAGE" | tee deployment-pipeline/containers/.last-image
