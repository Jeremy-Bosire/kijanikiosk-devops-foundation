# KijaniKiosk Payments — Service Level Objectives

## 1. Purpose and Scope

This document defines the reliability objectives for the KijaniKiosk Payments service. It establishes measurable indicators of availability, request success, and response latency.

The objectives use a rolling 30-day measurement window. They are intended to protect payment availability, detect unhealthy releases, and support automatic recovery.

## 2. Service Level Indicators (SLIs)

### SLI 1: Service Availability

**Definition:** The percentage of scheduled production health checks that successfully receive a healthy response from the active application through the Nginx production proxy.

**Measurement source:** Automated health monitor querying `/health` through the production proxy.

**Calculation:**

Availability (%) = (Successful health checks / Total scheduled health checks) × 100

A successful check must return HTTP 200 and the expected active application version.

### SLI 2: Successful Payment Request Rate

**Definition:** The percentage of valid payment requests that complete successfully.

**Measurement source:** Application request logs or an application monitoring platform, recording request outcomes and response status codes.

**Calculation:**

Success rate (%) = (Successful valid requests / Total valid requests) × 100

Successful requests are those returning successful 2xx responses. Server errors and dependency failures count as unsuccessful requests. Invalid client requests are excluded.

### SLI 3: Request Response Latency

**Definition:** The proportion of valid payment requests completed within 500 milliseconds, measured at the application boundary.

**Measurement source:** Application request-duration metrics or structured request logs.

**Calculation:**

Latency compliance (%) = (Valid requests completed within 500 ms / Total valid requests) × 100

The 95th-percentile response time should also be reported to identify slow requests that may affect customer experience.

## 3. Service Level Objectives (SLOs)

The following are proposed production targets, measured over a rolling 30-day window.

| SLI | SLO target | Measurement window |
|---|---:|---|
| Service availability | At least 99.9% | Rolling 30 days |
| Successful payment request rate | At least 99.5% | Rolling 30 days |
| Requests completed within 500 ms | At least 95% | Rolling 30 days |

### Error Budget

For the 99.9% availability objective, the permitted unavailability over a 30-day period is approximately 43.2 minutes.

This is the service's availability error budget. Sustained failures consume that budget and should trigger investigation and corrective action.

## 4. Automated Rollback Thresholds

Rollback thresholds are designed to detect unhealthy deployments before they cause prolonged customer impact.

| Condition | Threshold | Action | Relationship to SLO |
|---|---|---|---|
| Production health failure | 13 consecutive failed checks at 5-second intervals | Automatically switch traffic to the previously healthy environment | Protects the 99.9% availability objective |
| Elevated server errors | More than 5% server errors over 5 minutes, with at least 100 requests | Trigger rollback and investigate the release | Protects the 99.5% successful-request objective |
| Severe response latency | 95th-percentile latency above 1 second for 5 minutes, with at least 100 requests | Trigger rollback and investigate performance regression | Protects the 95% latency-compliance objective |

### Rollback Implementation and Verification

The current blue-green deployment implements automated rollback using production health checks.

The monitor checks the active release every five seconds. After 13 consecutive failed checks, it triggers the environment-switching script, which validates the previous environment and redirects production traffic.

The latest controlled failure test produced these results:

- Fault injected at 12:53:50 UTC.
- Automatic rollback triggered at 12:54:54 UTC.
- Blue environment verified healthy through the production proxy at 12:54:55 UTC.
- Total measured recovery time: 65 seconds.

This meets the assignment's requirement of completing recovery in under 90 seconds.

The elevated-error-rate and latency thresholds are proposed production safeguards. They require request-level monitoring and corresponding automated rollback integration; they have not yet been demonstrated by the current health-check monitor.

## 5. Exclusions

The following events may be excluded from SLO calculations when independently verified and documented:

1. **Invalid client requests:** Requests rejected because of invalid input or unsupported operations are excluded from the successful-request denominator. They must still be monitored separately to identify client integration problems.

2. **Independent monitoring infrastructure failures:** A health-check failure caused by an independently verified outage of the monitoring system may be excluded from availability calculations. The application must be checked using an alternative monitoring source before applying this exclusion.

3. **Verified external client-side connectivity failures:** Failures occurring entirely within a customer's device, local network, or internet connection before reaching the service may be excluded when supported by evidence. Failures within the service's own infrastructure or dependencies remain included.

Exclusions must be recorded with timestamps, supporting evidence, and an explanation. They must not be used to conceal genuine service failures.

Scheduled maintenance, application defects, deployment failures, and internal infrastructure outages are not automatically excluded.

## 6. Monitoring and Review

The engineering team should:

- Monitor production health continuously.
- Record request outcomes and response durations.
- Review availability, successful-request rate, and latency over rolling 30-day windows.
- Investigate sustained error-budget consumption.
- Review every automated rollback and document its cause and recovery duration.
- Reassess SLO targets when sufficient production traffic data becomes available.

## 7. Current Evidence and Limitations

The blue-green deployment has demonstrated successful traffic switching and automated rollback.

The latest controlled rollback completed in 65 seconds, with the Blue release returning HTTP 200 and version `v1.3.0` through the production proxy.

The current implementation verifies application health and release version. It does not yet provide historical 30-day availability measurements, payment-request success-rate statistics, or production latency distributions.

Consequently, the objectives in this document are proposed reliability targets rather than claims that the service has already achieved them.