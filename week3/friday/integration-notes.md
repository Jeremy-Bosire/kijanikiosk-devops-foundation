# Integration Challenge Resolutions

This document details the engineering analysis, trade-off evaluations, and architectural resolutions for the four integration challenges in the KijaniKiosk infrastructure baseline.

---

## Challenge A: `ProtectSystem=strict` and the EnvironmentFile Location

### The Conflict
Under `kk-payments.service`, achieving a `systemd-analyze security` score below 2.5 requires applying `ProtectSystem=strict`. This directive mounts the entire file system read-only for the service process, including `/opt/` and `/etc/`. Although `systemd` reads the `EnvironmentFile` (`/opt/kijanikiosk/config/payments-api.env`) as `root` *before* dropping privileges and executing the service, any attempt by the application to write logs to `/opt/kijanikiosk/shared/logs/` or write runtime state triggers a permission error.

### Options Considered
1. **Relocate environment and log files to standard FHS system directories (`/etc/kijanikiosk` and `/var/log/kijanikiosk`):**
   * *Pros:* Standard Linux distribution pattern; works cleanly with systemd defaults.
   * *Cons:* Violates the project brief requiring application files to reside in `/opt/kijanikiosk/`.
2. **Lower hardening strictness to `ProtectSystem=full`:**
   * *Pros:* Automatically leaves `/opt/` writable.
   * *Cons:* Increases the security score above the required 2.5 threshold, failing Requirement 6.
3. **Retain `ProtectSystem=strict` and utilize systemd path punching directives (`ReadWritePaths` and `ReadOnlyPaths`):**
   * *Pros:* Maintains maximum process isolation while explicitly defining resource boundaries.
   * *Cons:* Requires explicit path maintenance in unit files.

### Selected Resolution & Engineering Justification
**Option 3 was chosen.** The unit file for `kk-payments.service` incorporates explicit path exceptions:
```ini
ProtectSystem=strict
ReadOnlyPaths=/opt/kijanikiosk/config
ReadWritePaths=/opt/kijanikiosk/shared/logs
```

This resolution strictly preserves the process isolation model (< 2.5 security score) while permitting read access to configuration files and explicit write access to the shared log directory.

---

## Challenge B: The Monitoring User and Health Directory Access

### The Conflict
Requirement 1 mandates a Phase 8 monitoring health check that writes `/opt/kijanikiosk/health/last-provision.json`. The provisioning script executes as `root`, meaning newly created files default to `root:root` with `0644` or `0600` permissions. However, central monitoring utilities and the unprivileged service user `kk-logs` must read this status file without requiring `sudo` access.

### Options Considered
1. **Make `/opt/kijanikiosk/health/last-provision.json` world-readable (`0644`) owned by `root:root`:**
   * *Pros:* Simple to implement in bash.
   * *Cons:* Exposes internal health and port states to unauthenticated local accounts, violating least privilege principles.
2. **Apply Default POSIX ACLs to `/opt/kijanikiosk/health/`:**
   * *Pros:* Automatically updates permissions for any new file.
   * *Cons:* Overengineers a directory containing only a single static state file.
3. **Explicitly assign file ownership to `kk-logs:kijanikiosk` with `0640` permissions during Phase 8:**
   * *Pros:* Deterministic, simple, and strictly limits access to the `kijanikiosk` service group.
   * *Cons:* Requires explicit `chown`/`chmod` steps in the script after writing the file.

### Selected Resolution & Engineering Justification
**Option 3 was chosen.** In `kijanikiosk-provision.sh`, Phase 8 creates the directory with `0750` permissions (`root:kijanikiosk`), writes the status JSON file, and enforces ownership and mode:

```bash
chown kk-logs:kijanikiosk /opt/kijanikiosk/health/last-provision.json
chmod 0640 /opt/kijanikiosk/health/last-provision.json
```
This guarantees that `kk-logs` and any monitoring agent operating within the `kijanikiosk` group can read system status while keeping system telemetry isolated from unprivileged local users.

---

## Challenge C: `logrotate postrotate` and `PrivateTmp` Isolation

### The Conflict
When `logrotate` rotates application logs, open file descriptors held by running services point to the renamed archive files until re-opened. Standard log rotation configurations trigger a process reload (`systemctl reload <service>`). However, custom Node.js applications (`kk-api`, `kk-logs`) do not implement `ExecReload=` in their systemd unit files, causing `systemctl reload` to fail. Furthermore, `kk-logs.service` operates with `PrivateTmp=true`, isolating process-level file handling.

### Options Considered
1. **Use `copytruncate` in `/etc/logrotate.d/kijanikiosk`:**
   * *Pros:* Copies log file in place and truncates the original; requires no service restart.
   * *Cons:* High probability of log data loss during high-throughput stream writes between copy and truncate operations.
2. **Implement `ExecReload=/bin/kill -HUP $MAINPID` without application signal handling:**
   * *Pros:* Matches standard unit syntax.
   * *Cons:* Unhandled `SIGHUP` signals terminate Node.js processes immediately, crashing services.
3. **Issue `systemctl restart kk-logs.service` inside the logrotate `postrotate` block with directory user context (`su`):**
   * *Pros:* Safely resets file descriptors, works reliably without custom application signal handlers, and accommodates process-isolated temporary files.
   * *Cons:* Introduces a sub-second service restart during daily rotation.

### Selected Resolution & Engineering Justification
**Option 3 was chosen.** The logrotate configuration specifies an explicit `postrotate` restart and configures execution under `su kk-api kijanikiosk` to satisfy logrotate security constraints on group-writable directories:

```text
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
```

This guarantees reliable file descriptor reset across rotations without risking data corruption or unhandled signal crashes.

---

## Challenge D: Dirty VM Package Management & Version Holds

### The Conflict
During multi-day lab operations, package states drift. Packages such as `nginx` may be manually updated, partially configured, or placed on hold using `apt-mark hold`. Executing `apt-get install` against a dirty VM with active package holds or mismatched versions can break provisioning scripts or exit non-zero.

### Options Considered
1. **Force unhold, purge, and reinstall packages on every script run:**
   * *Pros:* Ensures exact package versions from scratch.
   * *Cons:* Destroys existing application configurations, increases script execution time, and fails idempotency tests.
2. **Ignore package management entirely if the binary exists:**
   * *Pros:* Avoids `apt` execution errors.
   * *Cons:* Fails to guarantee that required packages are installed and pinned against unauthorized upgrades.
3. **Idempotently check hold state via `apt-mark showhold` before attempting installation or hold assignment:**
   * *Pros:* Prevents redundant APT executions, respects existing correct holds, and handles dirty states gracefully.
   * *Cons:* Requires conditional checks before package operations.

### Selected Resolution & Engineering Justification
**Option 3 was chosen.** Phase 4 of `kijanikiosk-provision.sh` checks package hold status before issuing installation commands:

```bash
if apt-mark showhold | grep -q "^nginx$"; then
    log "Detected existing package hold: 'nginx'. Preserving hold state."
else
    apt-get update -qq && apt-get install -y -qq nginx
    apt-mark hold nginx >/dev/null
    log "Installed and pinned 'nginx'."
fi
```
This logic guarantees idempotent execution whether run on a clean VM, a machine with nginx pre-installed, or an environment where package holds were set manually during prior troubleshooting. 

