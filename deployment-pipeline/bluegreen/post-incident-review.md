# KijaniKiosk Post-Incident Review

## 1. Incident Summary and Impact

**Incident:** Staging environment outage during an investor demonstration.

**Duration:** 48 seconds.

**Environment:** KijaniKiosk staging environment.

**Severity:** Moderate.

**Impact:** The staging application became temporarily unavailable during the investor demonstration. This interrupted access to the application and affected the demonstration experience. The outage was resolved after service recovery.

**Customer impact:** No production customer impact is established by the scenario. The incident was limited to staging.

**Detection:** The outage was identified during the demonstration and required investigation and recovery.

## 2. Incident Timeline

The following timeline is reconstructed from the scenario. Exact timestamps were not provided.

| Event | Time |
|---|---|
| Staging service became unavailable | T+00 seconds |
| Outage identified | During the incident |
| Recovery process initiated | During the incident |
| Staging service restored | T+48 seconds |
| Total outage duration | 48 seconds |

The timestamps above are relative estimates, not verified system-log timestamps.

## 3. Root Cause Analysis — Five Whys

The following is a working root-cause hypothesis. Deployment logs and monitoring records should be reviewed before treating it as a confirmed technical cause.

**Why 1: Why did the investor demonstration experience an interruption?**

Because the staging application became temporarily unavailable.

**Why 2: Why did the staging application become unavailable?**

A deployment or service transition may have temporarily routed requests to an unhealthy or unavailable application instance.

**Why 3: Why could traffic reach an unhealthy instance?**

The deployment process may not have enforced sufficient health validation before making the new application instance available to users.

**Why 4: Why was health validation insufficient?**

The deployment process may have lacked a reliable automated mechanism for verifying application health through the actual production-facing proxy before completing a release.

**Why 5: Why was this weakness not identified earlier?**

Deployment testing and pre-demonstration operational checks may not have adequately covered unhealthy releases, traffic switching, and automatic recovery scenarios.

**Root-cause hypothesis:** Insufficient deployment health validation and failure-recovery safeguards allowed a staging release transition to interrupt service availability.

This hypothesis requires confirmation against the incident's deployment and application logs.

## 4. Contributing Factors

1. **Insufficient release validation:** The deployment process may not have fully verified application readiness before exposing the release to staging traffic.

2. **Inadequate failure simulation:** The deployment process may not have been tested against unhealthy application instances and failed traffic transitions.

3. **Monitoring limitations:** Health monitoring may not have detected or escalated the problem early enough to prevent the interruption.

4. **Demonstration readiness:** The staging environment may not have received a complete pre-demonstration health and deployment-readiness check.

## 5. Response and What Went Well

The staging service was restored after a 48-second interruption.

The incident highlighted the importance of deployment automation, health monitoring, and rollback procedures.

The subsequent Blue-Green deployment work provides a stronger recovery mechanism:

- Separate Blue and Green application environments.
- Independent health checks for each release.
- Nginx-based traffic switching.
- Automated rollback following consecutive failed health checks.
- Verification of the restored application through the production-facing proxy.

A controlled rollback test subsequently demonstrated recovery in 65 seconds, below the required 90-second target.

This later test demonstrates an improvement in the deployment process; it should not be interpreted as proof that the same mechanism was responsible for resolving the original 48-second incident.

## 6. Corrective and Preventive Actions

The following owners and timeframes are proposed estimates for the incident review.

| Action | Owner | Estimated timeframe | Expected outcome |
|---|---|---|---|
| Implement automated health checks before and after every deployment | DevOps Engineer | 2 working days | Unhealthy releases are detected before receiving traffic |
| Introduce automated rollback when deployment health checks fail | DevOps Engineer | 3 working days | Faster recovery from failed releases |
| Add staging failure-injection tests to deployment validation | QA Engineer | 5 working days | Deployment failures are identified before demonstrations |
| Establish pre-demonstration readiness checks and a deployment freeze | Release Manager | 2 working days | Reduces the risk of unplanned changes during demonstrations |
| Monitor availability, error rates, and response latency | Monitoring Engineer | 5 working days | Improves detection and visibility of service degradation |

### Follow-up and Review

The engineering team should review the corrective actions after implementation and verify that:

- Deployments cannot route traffic to unhealthy application instances.
- Failed releases trigger automatic recovery.
- Recovery is verified through the Nginx proxy.
- Monitoring provides visibility into service availability and application errors.
- Staging readiness is confirmed before important demonstrations.

The objective is to prevent recurrence, reduce service interruptions, and improve confidence in the KijaniKiosk deployment process.