#!/usr/bin/env bash
# KijaniKiosk IaC pipeline: Terraform provisions -> outputs become the Ansible
# inventory -> Ansible configures. Safe to run repeatedly; the second run must
# show "No changes" from Terraform and changed=0 from Ansible.
#
# Usage:
#   ./pipeline.sh [multipass|cloud]    provision + configure (default: multipass)
#   ./pipeline.sh destroy              tear everything down
#
#   LOG_FILE=pipeline-run1.log ./pipeline.sh multipass   # also write a log
#
# IP source (Integration Challenge A):
#   multipass - IPs read live from "multipass info <vm>" (VM names come from
#               terraform output vm_names) and cross-checked against Terraform.
#   cloud     - IPs read from "terraform output -raw <role>_server_ip".
#
# Exit code is non-zero if any stage fails.
set -Eeuo pipefail

MODE=${1:-multipass}
ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TF_DIR="$ROOT_DIR/terraform"
ANSIBLE_DIR="$ROOT_DIR/ansible"
INVENTORY="$ANSIBLE_DIR/inventory.ini"
KNOWN_HOSTS="$ANSIBLE_DIR/known_hosts.generated"
GROUP_VARS="$ANSIBLE_DIR/group_vars/kijanikiosk.yml"
ROLES=(api payments logs)

if [ -n "${LOG_FILE:-}" ]; then
  exec > >(tee -a "$LOG_FILE") 2>&1
fi

# Compatibility shim for Multipass 1.17+ launch output (see scripts/bin/multipass).
export PATH="$ROOT_DIR/scripts/bin:$PATH"

# Plain output so logs are readable.
export TF_IN_AUTOMATION=1 TF_INPUT=0
export ANSIBLE_NOCOLOR=1 ANSIBLE_FORCE_COLOR=0 PY_COLORS=0
export ANSIBLE_CONFIG="$ANSIBLE_DIR/ansible.cfg"
# MinIO credentials for the S3 backend. Defaults match scripts/start-minio.sh.
# Deliberately NOT inherited from any AWS_* already in the shell: real AWS
# credentials must never be sent to the local MinIO endpoint (or vice versa).
export AWS_ACCESS_KEY_ID="${MINIO_ROOT_USER:-minioadmin}"
export AWS_SECRET_ACCESS_KEY="${MINIO_ROOT_PASSWORD:-minioadmin}"
unset AWS_PROFILE AWS_SESSION_TOKEN

ts()     { date '+%Y-%m-%dT%H:%M:%S%z'; }
banner() { printf '\n==================== [%s] %s ====================\n' "$(ts)" "$*"; }
info()   { printf '[%s] %s\n' "$(ts)" "$*"; }
die()    { printf '[%s] PIPELINE FAILED: %s\n' "$(ts)" "$*" >&2; exit 1; }
trap 'rc=$?; printf "[%s] PIPELINE FAILED (exit %s) at line %s: %s\n" "$(ts)" "$rc" "$LINENO" "$BASH_COMMAND" >&2; exit "$rc"' ERR

tf() { terraform -chdir="$TF_DIR" "$@"; }

need() { command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"; }

# ---------------------------------------------------------------------------
preflight() {
  banner "Stage 0: preflight ($MODE)"
  case "$MODE" in multipass|cloud|destroy) ;; *) die "usage: $0 [multipass|cloud|destroy]" ;; esac
  for c in terraform ssh ssh-keyscan python3 curl; do need "$c"; done
  [ "$MODE" = destroy ] || { need ansible-playbook; need ansible-galaxy; }
  if [ "$MODE" != cloud ]; then need multipass; fi

  curl -fsS http://localhost:9000/minio/health/live >/dev/null \
    || die "MinIO is not reachable on http://localhost:9000 - run scripts/start-minio.sh"
  info "MinIO state backend reachable"

  info "Tool versions:"
  terraform version | sed -n 1p
  [ "$MODE" = destroy ] || ansible-playbook --version | sed -n 1p
  [ "$MODE" = cloud ] || multipass version | sed -n 1p
}

# ---------------------------------------------------------------------------
terraform_stage() {
  banner "Stage 1: Terraform"
  tf init -input=false -no-color
  tf validate -no-color

  local rc=0
  tf plan -input=false -no-color -detailed-exitcode -out=tfplan || rc=$?
  case "$rc" in
    0) info "Terraform plan: NO CHANGES - infrastructure matches configuration; skipping apply" ;;
    2) info "Terraform plan has changes - applying the saved plan"
       # One VM at a time: parallel launches on a small nested-virtualisation
       # host can exceed Multipass's launch timeout. Override with TF_PARALLELISM.
       tf apply -input=false -no-color -parallelism="${TF_PARALLELISM:-1}" tfplan ;;
    *) die "terraform plan failed (exit $rc)" ;;
  esac
  rm -f "$TF_DIR/tfplan"
}

# ---------------------------------------------------------------------------
tf_json() { tf output -json "$1"; }
json_get() { python3 -c 'import json,sys; print(json.load(sys.stdin)[sys.argv[1]])' "$1"; }

ip_for_role() {
  local role=$1 ip=""
  if [ "$MODE" = multipass ]; then
    local vm
    vm=$(tf_json vm_names | json_get "$role")
    ip=$(multipass info "$vm" | tr -d '\r' | awk '/IPv4/ {print $2; exit}')
  else
    ip=$(tf output -raw "${role}_server_ip")
  fi
  [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "no valid IPv4 for role '$role' (got '$ip')"
  echo "$ip"
}

handoff_stage() {
  banner "Stage 2: Terraform outputs -> Ansible inventory"

  # Integration Challenge B/C: the key and the SSH networks Terraform used must
  # be the ones Ansible uses. Fail here, not 40 tasks into the playbook.
  tf output -json > "$TF_DIR/.outputs.json"
  python3 - "$TF_DIR/.outputs.json" "$GROUP_VARS" <<'PY'
import json, os, sys, yaml
out = {k: v["value"] for k, v in json.load(open(sys.argv[1])).items()}
gv = yaml.safe_load(open(sys.argv[2]))
errors = []
tf_key = out["ssh_key_name"]
an_key = os.path.basename(gv["ansible_ssh_private_key_file"])
if tf_key != an_key:
    errors.append(f"SSH key mismatch: terraform ssh_key_name={tf_key} but ansible uses {an_key}")
if sorted(out["admin_cidrs"]) != sorted(gv["ssh_allowed_cidrs"]):
    errors.append(f"SSH network mismatch: terraform admin_cidrs={out['admin_cidrs']} ansible ssh_allowed_cidrs={gv['ssh_allowed_cidrs']}")
for e in errors:
    print("[handoff] " + e)
if errors:
    sys.exit(1)
print(f"[handoff] key '{tf_key}' and SSH networks match between Terraform and Ansible")
PY
  rm -f "$TF_DIR/.outputs.json"

  KEY_FILE="$HOME/.ssh/$(tf output -raw ssh_key_name)"
  SSH_USER=$(python3 -c 'import yaml,sys; print(yaml.safe_load(open(sys.argv[1]))["ansible_user"])' "$GROUP_VARS")
  [ -f "$KEY_FILE" ] || die "private key $KEY_FILE not found"

  declare -gA IPS=()
  local tf_ips role
  tf_ips=$(tf_json server_ips)
  for role in "${ROLES[@]}"; do
    IPS[$role]=$(ip_for_role "$role")
    local tf_ip
    tf_ip=$(echo "$tf_ips" | json_get "$role")
    if [ "$tf_ip" != "${IPS[$role]}" ]; then
      info "WARNING: $role IP from $MODE (${IPS[$role]}) differs from Terraform state ($tf_ip) - using $MODE value"
    fi
    info "kk-$role -> ${IPS[$role]}"
  done

  # Write the inventory atomically: a failed run never leaves a half-written file.
  local tmp
  tmp=$(mktemp "$ANSIBLE_DIR/.inventory.XXXXXX")
  {
    echo "# GENERATED by pipeline.sh ($MODE) at $(ts) - do not edit by hand."
    echo "# Source: $( [ "$MODE" = multipass ] && echo 'multipass info (cross-checked with terraform output server_ips)' || echo 'terraform output -raw <role>_server_ip')"
    echo "[kijanikiosk]"
    for role in "${ROLES[@]}"; do
      echo "kk-$role ansible_host=${IPS[$role]}"
    done
  } > "$tmp"
  mv "$tmp" "$INVENTORY"
  info "Wrote $INVENTORY:"
  cat "$INVENTORY"

  # Fresh VMs have fresh host keys. Record them now so Ansible can keep strict
  # host key checking on (trust-on-first-use at provisioning time).
  : > "$KNOWN_HOSTS.tmp"
  for role in "${ROLES[@]}"; do
    local ip=${IPS[$role]} ok=0
    for _ in $(seq 1 30); do
      if ssh-keyscan -T 5 -t ed25519 "$ip" 2>/dev/null | grep -q ssh-ed25519; then
        ssh-keyscan -T 5 -t ed25519 "$ip" 2>/dev/null >> "$KNOWN_HOSTS.tmp"; ok=1; break
      fi
      sleep 5
    done
    [ "$ok" = 1 ] || die "SSH on $ip (kk-$role) never answered - check the VM and admin_cidrs"
  done
  mv "$KNOWN_HOSTS.tmp" "$KNOWN_HOSTS"
  info "Recorded host keys for ${#ROLES[@]} servers"

  # Integration Challenge B/C: prove SSH works before handing over to Ansible.
  for role in "${ROLES[@]}"; do
    ssh -i "$KEY_FILE" -o BatchMode=yes -o ConnectTimeout=10 \
        -o UserKnownHostsFile="$KNOWN_HOSTS" -o StrictHostKeyChecking=yes \
        "$SSH_USER@${IPS[$role]}" true \
      || die "SSH test failed for kk-$role ($SSH_USER@${IPS[$role]}) with key $KEY_FILE"
    info "SSH OK: $SSH_USER@${IPS[$role]} (kk-$role)"
  done
}

# ---------------------------------------------------------------------------
ansible_stage() {
  banner "Stage 3: Ansible"
  cd "$ANSIBLE_DIR"
  ansible-galaxy collection install -r requirements.yml >/dev/null
  local out rc=0
  out=$(mktemp)
  ansible-playbook -i inventory.ini kijanikiosk.yml 2>&1 | tee "$out" || rc=${PIPESTATUS[0]}
  [ "$rc" -eq 0 ] || { rm -f "$out"; die "ansible-playbook failed (exit $rc)"; }

  local changed
  changed=$(grep -Eo ' changed=[0-9]+' "$out" | awk -F= '{s+=$2} END {print s+0}')
  rm -f "$out"
  banner "Result"
  info "Ansible total changed tasks across all hosts: $changed"
  if [ "$changed" -eq 0 ]; then
    info "IDEMPOTENT: servers already matched the specification (changed=0 on every host)"
  else
    info "Configuration applied. Run the pipeline again to prove changed=0."
  fi
}

# ---------------------------------------------------------------------------
destroy_stage() {
  banner "Destroy"
  tf init -input=false -no-color >/dev/null
  tf destroy -auto-approve -input=false -no-color
  rm -f "$KNOWN_HOSTS"
  # inventory.ini is left as the record of the last successful run; the next
  # pipeline run regenerates it, so stale IPs are never used.
  info "Servers destroyed. inventory.ini still shows the last run's hosts and is regenerated on the next run."
}

preflight
if [ "$MODE" = destroy ]; then
  destroy_stage
else
  terraform_stage
  handoff_stage
  ansible_stage
fi
banner "PIPELINE COMPLETE ($MODE)"
