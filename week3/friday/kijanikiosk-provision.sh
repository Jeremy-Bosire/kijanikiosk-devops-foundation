#!/bin/bash
# ==============================================================================
# Expected dirty conditions found in pre-provisioning audit:
# - kk-api already exists (UID 999): handled in Phase 2 by id check before useradd
# - kijanikiosk group exists (GID 1001): handled in Phase 2 by getent check
# - /opt/kijanikiosk/config has unsafe 0777 permissions: corrected to 0770 in Phase 3
# - /opt/kijanikiosk/shared/logs lacks multi-user ACLs: setfacl default rules applied in Phase 3
# - nginx package is on hold: verified and handled idempotently in Phase 4
# - ufw rules missing comments and proper rule ordering: reset and reconfigured in Phase 5
# ==============================================================================

set -euo pipefail

log() { echo -e "[INFO] $(date +'%Y-%m-%dT%H:%M:%S%z') - $1"; }
warn() { echo -e "[WARN] $(date +'%Y-%m-%dT%H:%M:%S%z') - $1"; }
error() { echo -e "[ERROR] $(date +'%Y-%m-%dT%H:%M:%S%z') - $1"; }

# ------------------------------------------------------------------------------
# Phase 1: Pre-flight & Root Check
# ------------------------------------------------------------------------------
log "Starting Phase 1: Pre-flight Checks"
if [[ $EUID -ne 0 ]]; then
   error "This script must be run as root (use sudo)."
   exit 1
fi

# ------------------------------------------------------------------------------
# Phase 2: System Users & Group Provisioning
# ------------------------------------------------------------------------------
log "Starting Phase 2: System Users & Group Provisioning"

if getent group kijanikiosk >/dev/null; then
    log "Already exists: group 'kijanikiosk'. Skipping creation."
else
    groupadd -r kijanikiosk
    log "Created group 'kijanikiosk'."
fi

for user in kk-api kk-payments kk-logs; do
    if id "$user" &>/dev/null; then
        log "Already exists: user '$user'. Skipping creation."
    else
        useradd -r -s /bin/false -g kijanikiosk "$user"
        log "Created service account user '$user'."
    fi
done

# ------------------------------------------------------------------------------
# Phase 3: Directory Structure, Permissions, & ACL Setup
# ------------------------------------------------------------------------------
log "Starting Phase 3: Directory Structure & Permissions Setup"

mkdir -p /opt/kijanikiosk/{config,shared/logs,health,app}

# Set directory base ownership & permissions
chown -R root:kijanikiosk /opt/kijanikiosk/config /opt/kijanikiosk/shared/logs /opt/kijanikiosk/app
chmod 0770 /opt/kijanikiosk/config /opt/kijanikiosk/shared/logs /opt/kijanikiosk/app

# Health directory owned by root:kijanikiosk, readable by group
chown root:kijanikiosk /opt/kijanikiosk/health
chmod 0750 /opt/kijanikiosk/health

# Apply Default ACLs for automatic inheritance on new files in shared/logs
setfacl -b /opt/kijanikiosk/shared/logs || true
setfacl -m m::rwx /opt/kijanikiosk/shared/logs
setfacl -m g:kijanikiosk:rwx /opt/kijanikiosk/shared/logs
setfacl -d -m g:kijanikiosk:rwx /opt/kijanikiosk/shared/logs
log "Applied default ACLs to /opt/kijanikiosk/shared/logs/."

# Create placeholder Environment Files if they don't exist
for envfile in api.env payments-api.env logs.env; do
    if [[ ! -f "/opt/kijanikiosk/config/$envfile" ]]; then
        echo "PORT=3000" > "/opt/kijanikiosk/config/$envfile"
        chown root:kijanikiosk "/opt/kijanikiosk/config/$envfile"
        chmod 0640 "/opt/kijanikiosk/config/$envfile"
        log "Created environment config file /opt/kijanikiosk/config/$envfile"
    fi
done

# ------------------------------------------------------------------------------
# Phase 4: Package Management & Holds
# ------------------------------------------------------------------------------
log "Starting Phase 4: Package Management"

if dpkg -l | grep -q "^ii  nginx "; then
    log "Package 'nginx' is already installed."
else
    log "Installing 'nginx'..."
    apt-get update -qq
    apt-get install -y -qq nginx
fi

# Ensure package hold is in place idempotently
if apt-mark showhold | grep -q "^nginx$"; then
    log "Package 'nginx' is already on hold."
else
    apt-mark hold nginx
    log "Placed package 'nginx' on hold."
fi

# ------------------------------------------------------------------------------
# Phase 5: Firewall Baseline Setup
# ------------------------------------------------------------------------------
log "Starting Phase 5: Firewall Baseline Setup"

# Reset ufw to known baseline state
ufw --force reset >/dev/null
ufw default deny incoming >/dev/null
ufw default allow outgoing >/dev/null

# Rule Ordering Matters: Allow loopback 3001 BEFORE external deny 3001
ufw allow in on lo to any port 3001 comment "Allow internal loopback to payments" >/dev/null
ufw allow 22/tcp comment "Allow SSH access" >/dev/null
ufw allow 80/tcp comment "Allow HTTP traffic" >/dev/null
ufw allow from 10.0.1.0/24 to any port 3001 comment "Allow monitoring subnet to payments check" >/dev/null
ufw deny 3001/tcp comment "Deny external direct access to payments" >/dev/null

ufw --force enable >/dev/null
log "Firewall successfully re-initialized and enabled."

# ------------------------------------------------------------------------------
# Phase 6: Systemd Unit Provisioning & Hardening
# ------------------------------------------------------------------------------
log "Starting Phase 6: systemd Unit Files Setup"

# 1. kk-api.service (Score < 3.5)
cat <<'EOF' > /etc/systemd/system/kk-api.service
[Unit]
Description=KijaniKiosk API Service
After=network.target

[Service]
Type=simple
User=kk-api
Group=kijanikiosk
EnvironmentFile=/opt/kijanikiosk/config/api.env
ExecStart=/usr/bin/python3 -m http.server 3000
Restart=always

# Hardening
ProtectSystem=full
ProtectHome=true
PrivateTmp=true
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF

# 2. kk-payments.service (Score < 2.5)
cat <<'EOF' > /etc/systemd/system/kk-payments.service
[Unit]
Description=KijaniKiosk Payments Service
After=network.target kk-api.service
Wants=kk-api.service

[Service]
Type=simple
User=kk-payments
Group=kijanikiosk
EnvironmentFile=/opt/kijanikiosk/config/payments-api.env
ExecStart=/usr/bin/python3 -m http.server 3001
Restart=always

# Advanced Hardening (<2.5 Score)
ProtectSystem=strict
ReadOnlyPaths=/opt/kijanikiosk/config
ReadWritePaths=/opt/kijanikiosk/shared/logs
ProtectHome=true
PrivateTmp=true
NoNewPrivileges=true
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true
RestrictAddressFamilies=AF_INET AF_INET6 AF_UNIX
MemoryDenyWriteExecute=true
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
LockPersonality=true

[Install]
WantedBy=multi-user.target
EOF

# 3. kk-logs.service (Score < 3.5)
cat <<'EOF' > /etc/systemd/system/kk-logs.service
[Unit]
Description=KijaniKiosk Logging Service
After=network.target

[Service]
Type=simple
User=kk-logs
Group=kijanikiosk
EnvironmentFile=/opt/kijanikiosk/config/logs.env
ExecStart=/usr/bin/python3 -m http.server 3002
Restart=always

# Hardening
ProtectSystem=full
ProtectHome=true
PrivateTmp=true
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF

chmod 0644 /etc/systemd/system/kk-*.service
systemctl daemon-reload
systemctl enable kk-api.service kk-payments.service kk-logs.service >/dev/null
log "systemd unit files written and enabled."

# ------------------------------------------------------------------------------
# Phase 7: Journal Persistence & Log Rotation
# ------------------------------------------------------------------------------
log "Starting Phase 7: Journal Persistence & Log Rotation"

mkdir -p /var/log/journal
mkdir -p /etc/systemd/journald.conf.d

cat <<'EOF' > /etc/systemd/journald.conf.d/00-journal-size.conf
[Journal]
Storage=persistent
SystemMaxUse=500M
EOF

systemctl restart systemd-journald

# Added 'su kk-api kijanikiosk' to satisfy parent directory security requirements
cat <<'EOF' > /etc/logrotate.d/kijanikiosk
/opt/kijanikiosk/shared/logs/*.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    su kk-api kijanikiosk
    create 0640 kk-api kijanikiosk
    postrotate
        systemctl restart kk-logs.service >/dev/null 2>&1 || true
    endscript
}
EOF

# Strict logrotate config permissions required by logrotate daemon
chmod 0644 /etc/logrotate.d/kijanikiosk
chown root:root /etc/logrotate.d/kijanikiosk

logrotate --debug /etc/logrotate.d/kijanikiosk >/dev/null 2>&1
log "Journal persistence configured (500MB cap) and logrotate verified."

# ------------------------------------------------------------------------------
# Phase 8: Monitoring Health Checks
# ------------------------------------------------------------------------------
log "Starting Phase 8: Monitoring Health Check File Generation"

api_status=$(timeout 2 bash -c "echo >/dev/tcp/localhost/3000" 2>/dev/null && echo '"ok"' || echo '"down"')
payments_status=$(timeout 2 bash -c "echo >/dev/tcp/localhost/3001" 2>/dev/null && echo '"ok"' || echo '"down"')

printf '{"timestamp":"%s","kk-api":%s,"kk-payments":%s}\n' \
  "$(date -Is)" "$api_status" "$payments_status" \
  > /opt/kijanikiosk/health/last-provision.json

chown kk-logs:kijanikiosk /opt/kijanikiosk/health/last-provision.json
chmod 0640 /opt/kijanikiosk/health/last-provision.json
log "Health check output written to /opt/kijanikiosk/health/last-provision.json."

# ------------------------------------------------------------------------------
# Final Verification Phase
# ------------------------------------------------------------------------------
log "Starting Final Verification Phase"
failed_checks=0

# 1. Verify Directories & Permissions
if [[ $(stat -c "%a" /opt/kijanikiosk/config) == "770" ]]; then
    echo "[PASS] /opt/kijanikiosk/config mode is 0770"
else
    echo "[FAIL] /opt/kijanikiosk/config permissions invalid"
    ((failed_checks++))
fi

# 2. Verify Firewall Rules Programmatically
ufw_status=$(ufw status)

if echo "$ufw_status" | grep -q "22/tcp.*ALLOW"; then
    echo "[PASS] SSH (22/tcp) rule present"
else
    echo "[FAIL] SSH (22/tcp) rule missing"
    ((failed_checks++))
fi

if echo "$ufw_status" | grep -q "80/tcp.*ALLOW"; then
    echo "[PASS] HTTP (80/tcp) rule present"
else
    echo "[FAIL] HTTP (80/tcp) rule missing"
    ((failed_checks++))
fi

if echo "$ufw_status" | grep -q "3001/tcp.*DENY"; then
    echo "[PASS] External port 3001 DENY rule present"
else
    echo "[FAIL] External port 3001 DENY rule missing"
    ((failed_checks++))
fi

if echo "$ufw_status" | grep -q "3001 on lo.*ALLOW"; then
    echo "[PASS] Loopback port 3001 ALLOW rule present"
else
    echo "[FAIL] Loopback port 3001 ALLOW rule missing"
    ((failed_checks++))
fi

# 3. Verify Logrotate Syntax
if logrotate --debug /etc/logrotate.d/kijanikiosk >/dev/null 2>&1; then
    echo "[PASS] logrotate config syntax valid"
else
    echo "[FAIL] logrotate config failed debug check"
    ((failed_checks++))
fi

# 4. Verify Health Check JSON File
if [[ -f /opt/kijanikiosk/health/last-provision.json ]]; then
    echo "[PASS] Health check JSON file exists"
else
    echo "[FAIL] Health check JSON file missing"
    ((failed_checks++))
fi

if [[ $failed_checks -eq 0 ]]; then
    log "ALL VERIFICATION CHECKS PASSED SUCCESSFULLY."
    exit 0
else
    error "$failed_checks verification check(s) failed."
    exit 1
fi
