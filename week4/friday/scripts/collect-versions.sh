#!/usr/bin/env bash
# Records the exact tool versions used for the pipeline runs into
# environment-setup.md (between the versions markers). Run it from WSL after
# the second pipeline run, before committing.
set -euo pipefail
ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
DOC="$ROOT_DIR/environment-setup.md"

v() { "$@" 2>/dev/null | tr -d '\r' | head -1 || echo "not installed"; }

win_ver="n/a"
if command -v cmd.exe >/dev/null 2>&1; then
  win_ver=$( (cd /mnt/c && cmd.exe /c ver) 2>/dev/null | tr -d '\r' | grep -m1 . || echo unknown)
fi
wsl_ver="n/a"
if command -v wsl.exe >/dev/null 2>&1; then
  wsl_ver=$(wsl.exe --version 2>/dev/null | tr -d '\0\r' | head -1 || echo unknown)
fi
minio_ver=$(docker exec minio minio --version 2>/dev/null | head -1 || echo "container 'minio' not running")
minio_img=$(docker inspect -f '{{.Config.Image}}' minio 2>/dev/null || echo unknown)

# shellcheck disable=SC1091
table=$(cat <<EOF
| Tool | Version (recorded $(date '+%Y-%m-%d %H:%M %z')) |
| :--- | :--- |
| Host OS (Windows) | ${win_ver} |
| WSL | ${wsl_ver} |
| WSL distro | $(. /etc/os-release && echo "$PRETTY_NAME") / kernel $(uname -r) |
| Terraform | $(v terraform version) |
| Terraform multipass provider | $(grep -A1 'larstobi/multipass' "$ROOT_DIR/terraform/.terraform.lock.hcl" 2>/dev/null | awk -F'"' '/version/ {print $2}' || echo unknown) |
| Multipass | $(v multipass version) |
| Ansible | $(v ansible --version) |
| Python (WSL) | $(v python3 --version) |
| Docker | $(v docker --version) |
| MinIO | ${minio_ver} (image: ${minio_img}) |
| OpenSSH client | $(ssh -V 2>&1 | head -1) |
| Guest OS image | Ubuntu 22.04 LTS (multipass image alias "22.04") |
EOF
)

python3 - "$DOC" "$table" <<'PY'
import re, sys
doc, table = sys.argv[1], sys.argv[2]
s = open(doc).read()
s = re.sub(r"(<!-- versions:start -->\n).*?(\n<!-- versions:end -->)",
           lambda m: m.group(1) + table + m.group(2), s, flags=re.S)
open(doc, "w").write(s)
PY
echo "$table"
echo "Updated $DOC"
