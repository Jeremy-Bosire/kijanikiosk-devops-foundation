# KijaniKiosk API Server - Triage Report

**Date:** 2026-09-29
**Investigated by:** Jeremy Bosire
**Server:** CR7
**Incident start (approximate):** 03:45:10 in the supplied application log (2024-01-15; historical/simulated timestamp)

## Summary

The investigation found no evidence of current CPU, memory, disk, or network saturation on the server.

The current system has a load average of `0.00`, approximately 3.2 GiB of available memory, no swap usage, and only 1% usage on the Linux root filesystem. No zombie or uninterruptible (`D`) processes were observed. NGINX is active and successfully serving HTTP requests on port 80.

The main application-level signal comes from the supplied `/var/log/kijanikiosk/app.log`. The log shows a progression from database connection-pool saturation to pool exhaustion, query timeouts, and eventually repeated `ECONNREFUSED database:5432` errors followed by database connection failure.

However, the application log timestamps are dated `2024-01-15`, while the current server investigation was performed on `2026-09-29`. Therefore, these entries should be treated as historical/simulated evidence rather than telemetry from the current six-hour incident window.

The current server state also shows no Node.js application process, no KijaniKiosk application service, no PostgreSQL service, and no local listener on TCP port 5432. The hostname `database` does not resolve from the server. These observations indicate that the expected application/database runtime is currently absent or unavailable, although the evidence does not establish why.

A secondary operational issue is the approximately 271 MB `/var/log/kijanikiosk/access.log.1`, which suggests a log rotation/retention problem. It is not currently causing disk exhaustion because the root filesystem is only 1% utilized.

## Process and Resource State

* System load average: `0.00, 0.00, 0.00`.
* Memory: approximately 509 MiB used out of 3.7 GiB, with approximately 3.2 GiB available.
* Swap: 1.0 GiB configured and currently unused.
* No significant CPU-consuming processes were observed.
* The highest-memory processes were normal system services such as `unattended-upgrade-shutdown`, `networkd-dispatcher`, and `systemd-journald`.
* No zombie (`Z`) processes were observed.
* No processes in uninterruptible sleep (`D` state) were observed.
* No obvious file-descriptor exhaustion was identified.
* No Node.js/`npm` process was found.
* `/opt/kijanikiosk/app/` exists but is empty.
* No KijaniKiosk, Node.js, or PostgreSQL systemd service was found.

**Assessment:** Current host resource utilization is healthy. There is no evidence that CPU, memory pressure, process-state exhaustion, or file-descriptor exhaustion is currently responsible for service degradation. The absence of the expected application process is, however, a significant current-state observation.

## Filesystem and Disk

The Linux root filesystem is:

* Size: approximately 1007 GB
* Used: approximately 1.8 GB
* Available: approximately 954 GB
* Utilization: `1%`

The KijaniKiosk log directory occupies approximately 271 MB:

* `access.log.1`: approximately 271 MB
* `app.log`: 776 bytes

`access.log.1` is the only log file found above 50 MB and is approximately 283 MB in raw size. This is unusually large for a rotated access log and is consistent with a possible log-rotation or retention issue.

Despite the large rotated log, the filesystem has substantial free capacity and there is no current disk-space pressure.

**Assessment:** Disk exhaustion is not a current incident cause. The oversized rotated access log should nevertheless be investigated because continued uncontrolled growth could become an operational risk.

## Log Analysis

The supplied `/var/log/kijanikiosk/app.log` contains 3 warnings and 6 errors.

The sequence of events is:

1. `03:45:10` — Database connection pool reached 85% capacity.
2. `04:01:33` — Database connection pool reached 94% capacity.
3. `04:07:55` — Connection pool became exhausted and requests were queued.
4. `04:08:01` — A 30-second query timeout occurred for `orders`.
5. `04:08:01` — A 30-second query timeout occurred for `products`.
6. `04:09:12` — Application reported memory usage at 87%.
7. `06:22:18` — `ECONNREFUSED database:5432`.
8. `06:22:23` — A second `ECONNREFUSED database:5432`.
9. `06:22:28` — Retry limit was reached and the database connection failed.

The progression from increasing connection-pool utilization to pool exhaustion, query timeouts, and subsequent connection-refused errors provides a coherent historical indication of database connectivity or availability problems.

There was no corresponding evidence of an OOM kill, I/O error, or disk exhaustion in the current system logs. A kernel log match for "disk quota" was observed, but it was a quota-related initialization message rather than evidence of an active disk-quota incident.

The available authentication-log search showed a sudo event corresponding to the investigation; no additional SSH authentication failures were identified in the examined output.

**Important timestamp caveat:** The application log is dated `2024-01-15`, so its events cannot be treated as current events from the `2026-09-29` investigation window.

## Network and Service State

NGINX is currently healthy:

* Service state: `active (running)`
* Listening on: TCP port 80 on IPv4 and IPv6
* NGINX configuration test: successful
* `GET /`: HTTP 200
* Response time for `/`: approximately 40 ms

No listeners were found on the commonly expected application/database ports:

* TCP 443: not listening
* TCP 3000: not listening
* TCP 8080: not listening
* TCP 5432: not listening

A direct connection attempt to `localhost:5432` returned `Connection refused`.

The hostname `database` referenced by the historical application log does not resolve through the server's configured name-resolution sources.

The complete listening-socket inspection showed no established TCP connection storm, and the socket summary reported zero established TCP connections at the time of investigation.

**Assessment:** NGINX is operational, but the expected backend application and local database services are not currently visible. Because the historical application log references `database:5432` rather than `localhost:5432`, the local port check alone does not establish that the intended database is supposed to run locally. The failure to resolve `database` is nevertheless significant and should be investigated if that hostname remains part of the application's intended configuration.

## Assessment

The current server does not exhibit resource exhaustion. CPU, memory, disk, and network connection levels are all within healthy ranges, and NGINX is serving requests successfully.

The strongest application-level evidence is the historical database-related sequence in `app.log`: connection-pool utilization increased from 85% to 94%, the pool became exhausted, queries timed out, and later connection attempts to `database:5432` were refused. This supports a hypothesis of database availability/connectivity problems contributing to application degradation during the period represented by the supplied log.

However, the current investigation cannot establish a definitive root cause because:

* The application log is timestamped `2024-01-15`, not within the current `2026-09-29` incident window.
* No Node.js application process is currently running.
* `/opt/kijanikiosk/app/` is empty.
* No KijaniKiosk or PostgreSQL systemd service is present.
* The hostname `database` does not currently resolve.
* There is no local listener on port 5432.

The 271 MB rotated access log represents a separate log-management concern but is not causing current filesystem pressure.

## Recommended Next Steps

1. **Verify and restore the intended application/database runtime path.** Confirm where the KijaniKiosk Node.js application and database are expected to run, then verify the application process/service, database endpoint, DNS resolution for `database`, and connectivity to the configured database port.

2. **Investigate the database connection-pool failure using contemporaneous application and database telemetry.** Collect current application logs, database availability/health information, connection-pool metrics, and database-side logs to determine whether connection exhaustion, database unavailability, or another dependency failure caused the historical timeout sequence.

3. **Correct log rotation and retention for KijaniKiosk access logs.** Review the rotation configuration for `/var/log/kijanikiosk/access.log` and establish appropriate rotation, compression, retention, and monitoring thresholds to prevent uncontrolled log growth.

