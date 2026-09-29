# KijaniKiosk Access Control Model & Directory Specification

## Overview
This document defines the production access control architecture for the KijaniKiosk infrastructure baseline. It establishes principal identities, directory permissions, access control lists (ACLs), and log rotation survival specifications across all service components.

---

## 1. Identity & Group Model

### System Users (Service Accounts)
All service processes run under dedicated, unprivileged system accounts with interactive logins disabled (`/bin/false`):

* **`kk-api`**: Runs the primary API service on port 3000.
* **`kk-payments`**: Runs the financial transactions service on port 3001.
* **`kk-logs`**: Runs the central logging collector and health monitoring ingestion.

### Primary Group
* **`kijanikiosk`**: Shared group comprising `kk-api`, `kk-payments`, and `kk-logs`. Used to grant explicit group-level filesystem permissions across shared resources.

---

## 2. Directory & Permissions Matrix

| Path | Owner | Group | Mode | Default ACLs (`setfacl`) | Purpose |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `/opt/kijanikiosk/` | `root` | `kijanikiosk` | `0755` | None | Application root directory |
| `/opt/kijanikiosk/app/` | `root` | `kijanikiosk` | `0755` | None | Executable application code |
| `/opt/kijanikiosk/config/` | `root` | `kijanikiosk` | `0770` | None | Environment files (`*.env`) |
| `/opt/kijanikiosk/shared/logs/` | `root` | `kijanikiosk` | `0775` | `g:kijanikiosk:rwx` | Shared application logs |
| `/opt/kijanikiosk/health/` | `root` | `kijanikiosk` | `0750` | None | Health status logs (`last-provision.json`) |

---

## 3. Directory Breakdown & ACL Rules

### `/opt/kijanikiosk/config/`
* **Permissions:** `0770` (`drwxrwx---`), `root:kijanikiosk`.
* **Files:** Environment files (`api.env`, `payments-api.env`, `logs.env`) set to mode `0640` (`-rw-r-----`).
* **Rationale:** Protects sensitive API credentials, database strings, and secret keys from unauthenticated system users while permitting read access to service processes belonging to the `kijanikiosk` group.

### `/opt/kijanikiosk/shared/logs/`
* **Permissions:** `0775` (`drwxrwxr-x`), `root:kijanikiosk`.
* **Default ACL Specification:** 
  ```bash
  setfacl -R -m g:kijanikiosk:rwx /opt/kijanikiosk/shared/logs
  setfacl -R -d -m g:kijanikiosk:rwx /opt/kijanikiosk/shared/logs

* **Rationale:** Multiple independent service accounts (`kk-api`, `kk-payments`, `kk-logs`) write and consume log stream data in this directory. Default inheritance (`setfacl -d`) ensures that any newly created log file automatically inherits `rwx` permissions for the `kijanikiosk` group, preventing silent log write blocks across service boundaries.

### `/opt/kijanikiosk/health/` *(New Phase 8 Addition)*
* **Permissions:** `0750` (`drwxr-x---`), `root:kijanikiosk`.
* **File Permissions:** `/opt/kijanikiosk/health/last-provision.json` set to `0640` (`-rw-r-----`), owned by `kk-logs:kijanikiosk`.
* **Rationale:** Created to house automated monitoring output. The provisioning script generates this status file as `root` and immediately transfers ownership to `kk-logs:kijanikiosk`. This allows `kk-logs` and non-root monitoring agents within the `kijanikiosk` group to inspect health status without needing `sudo` privileges.

---

## 4. Logrotate Interaction & Access Model Survival

When `logrotate` executes daily via `cron`, rotated files are compressed and replaced with fresh, empty log files.

### Rotation Mechanics
1. **Directory Security Enforcement:** On Debian/Ubuntu platforms, `logrotate` refuses to process directories writable by non-root groups unless `su` is explicitly specified. The `/etc/logrotate.d/kijanikiosk` configuration enforces execution under `kk-api kijanikiosk`:
   ```text
   su kk-api kijanikiosk
   create 0640 kk-api kijanikiosk

2. **ACL Inheritance:** When a new log file is created by logrotate, standard `create 0640` sets POSIX base mode. The directory's default ACL (`setfacl -d -m g:kijanikiosk:rwx`) immediately propagates to the newly created file, enabling `kk-payments` and `kk-logs` to read/write without manual intervention.

### Verification Protocol
To verify that the access model survives rotation, run a forced rotation followed by a non-root write test:

```bash
sudo logrotate --force /etc/logrotate.d/kijanikiosk
sudo -u kk-api touch /opt/kijanikiosk/shared/logs/test-write.tmp
```

A successful file creation proves that rotation does not degrade service log capabilities. 

