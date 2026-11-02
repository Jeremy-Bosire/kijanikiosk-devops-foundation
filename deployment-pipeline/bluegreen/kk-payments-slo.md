# kk-payments service-level objectives

| SLI | Data source | Calculation method | Measurement window |
|---|---|---|---|
| Availability | nginx access logs plus the health endpoint | Successful health and payment requests divided by all valid requests, excluding retry traffic explicitly logged by the proxy | Rolling 30 days, measured continuously |
| Latency | nginx access-log response times or a hypothetical histogram exported per route | Percentage of payment requests completed within 300 milliseconds; calculate from completed requests only | Rolling 30 days |
| Payment error rate | nginx access logs correlated with the payment application response | Requests with an application or upstream error response divided by all payment requests | Rolling 30 days |

## Proposed targets (not yet measured against production traffic)

| SLI | SLO target | Measurement window |
|---|---|---|
| Availability | At least 99.9% successful valid requests | Rolling 30 days |
| Latency | At least 95% of payment requests complete within 300 milliseconds | Rolling 30 days |
| Payment error rate | At most 0.5% of payment requests return an application or upstream error | Rolling 30 days |

## Automated rollback thresholds

| SLI | Short-window threshold | Relationship to SLO |
|---|---|---|
| Availability | Below 98% over 60 seconds, after three consecutive failed checks | More tolerant of a brief probe miss, but substantially stricter than consuming the normal error budget |
| Latency | More than 10% of requests over 300 milliseconds across the 60-second window | Trigger is intended to detect a release regression sooner than the 30-day objective |
| Payment error rate | Above 2% across 60 seconds, with at least 100 requests | Detects rapid deterioration while avoiding tiny-sample alarms |

## What we do not commit to

**Throughput:** Peak requests per second is an operational capacity metric, not a user-visible promise and will not trigger this objective.

**Business conversion:** Checkout completion after a payment is accepted depends on later systems, so it is excluded from this payment-service contract.
