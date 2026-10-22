#!/usr/bin/env bash
# Start (or reuse) the local MinIO state backend and make sure the state bucket
# exists with versioning on. Safe to run any number of times.
#
# Why not minio/minio? MinIO archived the community edition in late 2025 and
# its Docker Hub / quay.io images and binaries no longer pull. Chainguard
# rebuilds MinIO from source and publishes it free; we use that image. If you
# still have minio/minio cached from Wednesday, set MINIO_IMAGE to use it.
set -euo pipefail

MINIO_IMAGE=${MINIO_IMAGE:-cgr.dev/chainguard/minio:latest}
MC_IMAGE=${MC_IMAGE:-cgr.dev/chainguard/minio-client:latest}
MINIO_ROOT_USER=${MINIO_ROOT_USER:-minioadmin}
MINIO_ROOT_PASSWORD=${MINIO_ROOT_PASSWORD:-minioadmin}
BUCKET=${TF_STATE_BUCKET:-kijanikiosk-tfstate}
# Named volume = state survives container restarts and removals (Challenge E).
VOLUME=${MINIO_VOLUME:-kijanikiosk-minio-data}

if docker ps --format '{{.Names}}' | grep -qx minio; then
  echo "[minio] container already running"
elif docker ps -a --format '{{.Names}}' | grep -qx minio; then
  echo "[minio] starting existing container"
  docker start minio >/dev/null
else
  echo "[minio] creating container from ${MINIO_IMAGE} (data volume: ${VOLUME})"
  docker run -d --name minio --restart unless-stopped \
    -p 9000:9000 -p 9001:9001 \
    -e MINIO_ROOT_USER="${MINIO_ROOT_USER}" \
    -e MINIO_ROOT_PASSWORD="${MINIO_ROOT_PASSWORD}" \
    -v "${VOLUME}:/data" \
    "${MINIO_IMAGE}" server /data --console-address :9001 >/dev/null
fi

echo -n "[minio] waiting for http://localhost:9000 "
for _ in $(seq 1 30); do
  if curl -fsS http://localhost:9000/minio/health/live >/dev/null 2>&1; then echo "up"; break; fi
  echo -n "."; sleep 1
done
curl -fsS http://localhost:9000/minio/health/live >/dev/null || { echo; echo "[minio] did not come up"; exit 1; }

mc() {
  docker run --rm --network host \
    -e MC_HOST_local="http://${MINIO_ROOT_USER}:${MINIO_ROOT_PASSWORD}@localhost:9000" \
    "${MC_IMAGE}" "$@"
}
mc mb --ignore-existing "local/${BUCKET}"
# Versioning keeps every previous state file - a corrupted or wrong state can be rolled back.
mc version enable "local/${BUCKET}"
echo "[minio] console: http://localhost:9001  (bucket: ${BUCKET})"
