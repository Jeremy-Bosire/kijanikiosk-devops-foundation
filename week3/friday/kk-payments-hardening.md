# `kk-payments.service` Hardening & Security Audit Log

## 1. Overview & Security Score Summary
This document logs the systemd service security analysis and hardening process for `kk-payments.service`. The objective was to lower the exposure score evaluated by `systemd-analyze security` below **2.5** (OK) while preserving full transaction processing capabilities and log access.

* **Initial Unhardened Exposure Score:** `9.6 / 10` (UNSAFE)
* **Final Hardened Exposure Score:** `2.3 / 10` (OK)

---

## 2. Hardening Directives Applied

| Directive | Risk Mitigation | Score Impact |
| :--- | :--- | :--- |
| `NoNewPrivileges=yes` | Prevents child processes from gaining elevated privileges via setuid/setgid binaries. | High |
| `ProtectSystem=strict` | Mounts `/`, `/usr`, `/boot`, `/etc`, and `/opt` as read-only. | High |
| `ProtectHome=yes` | Restricts access to `/home`, `/root`, and `/run/user`. | Medium |
| `PrivateTmp=yes` | Isolates `/tmp` and `/var/tmp` in a private process namespace. | Medium |
| `PrivateDevices=yes` | Denies access to physical devices (`/dev/sda`, `/dev/mem`, etc.). | Medium |
| `ProtectKernelTunables=yes` | Denies modification of `/proc/sys`, `/sys`, etc. | Medium |
| `ProtectKernelModules=yes` | Prevents loading or unloading of Linux kernel modules. | Low |
| `ProtectControlGroups=yes` | Mounts cgroup hierarchies as read-only. | Low |
| `ProtectKernelLogs=yes` | Denies access to `/dev/kmsg` and kernel ring buffer. | Low |
| `ProtectClock=yes` | Denies system time and RTC clock modifications. | Low |
| `CapabilityBoundingSet=` | Drops all kernel capabilities (`CAP_SYS_ADMIN`, `CAP_NET_ADMIN`, etc.). | High |
| `RestrictRealtime=yes` | Prevents realtime scheduling class assignment. | Low |
| `RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6` | Limits networking to UNIX sockets and IPv4/IPv6 stacks. | Medium |
| `ProtectProc=invisible` | Restricts process visibility in `/proc` to owned PIDs. | Low |
| `ProcSubset=pid` | Hides non-PID entries from `/proc`. | Low |
| `LockPersonality=yes` | Locks down execution domain changes. | Low |
| `RestrictNamespaces=yes` | Denies creation of user, mount, or PID Linux namespaces. | Medium |
| `ReadOnlyPaths=/opt/kijanikiosk/config` | Ensures environment file (`payments-api.env`) is immutable during execution. | Key Requirement |
| `ReadWritePaths=/opt/kijanikiosk/shared/logs` | Punch-hole exception to allow log writing under `ProtectSystem=strict`. | Key Requirement |

---

## 3. Rejected Directives & Engineering Trade-offs

### 1. `PrivateNetwork=yes`
* **Status:** REJECTED
* **Justification:** The `kk-payments` service processes external payment gateway transactions over HTTP/HTTPS (port 3001). Enabling network namespace isolation (`PrivateNetwork=yes`) disconnects network interfaces, breaking payment processing.

### 2. `DynamicUser=yes`
* **Status:** REJECTED
* **Justification:** `DynamicUser=yes` assigns transient ephemeral UIDs/GIDs upon process start. Because log files in `/opt/kijanikiosk/shared/logs/` require persistent group ownership (`kijanikiosk`), dynamic allocation breaks group-level ACL write permissions and daily log rotation consistency.

### 3. `MemoryDenyWriteExecute=yes`
* **Status:** REJECTED
* **Justification:** The Node.js application runtime utilizes V8 Just-In-Time (JIT) compilation, which requires allocating writable memory regions and executing code from them. Enforcing `MemoryDenyWriteExecute=yes` causes immediate runtime segmentation faults during V8 JIT code generation.

---

## 4. Final Hardened Unit File (`/etc/systemd/system/kk-payments.service`)

```ini
[Unit]
Description=KijaniKiosk Payments Service
After=network.target

[Service]
Type=simple
User=kk-payments
Group=kijanikiosk
WorkingDirectory=/opt/kijanikiosk/app
EnvironmentFile=/opt/kijanikiosk/config/payments-api.env
ExecStart=/usr/bin/node /opt/kijanikiosk/app/payments.js

# Sandbox & Security Hardening
NoNewPrivileges=yes
ProtectSystem=strict
ProtectHome=yes
PrivateTmp=yes
PrivateDevices=yes
ProtectKernelTunables=yes
ProtectKernelModules=yes
ProtectControlGroups=yes
ProtectKernelLogs=yes
ProtectClock=yes
CapabilityBoundingSet=
RestrictRealtime=yes
RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6
ProtectProc=invisible
ProcSubset=pid
LockPersonality=yes
RestrictNamespaces=yes

# Path Specific Boundary Exceptions
ReadOnlyPaths=/opt/kijanikiosk/config
ReadWritePaths=/opt/kijanikiosk/shared/logs

Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```
