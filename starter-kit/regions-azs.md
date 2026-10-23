# Region and Availability Zone Design

## Region: `af-south-1` (Cape Town)

| Factor | af-south-1 (Cape Town) | eu-west-1 (Ireland) | Why it matters |
|---|---|---|---|
| Distance to customers in Kenya | Same continent, noticeably lower latency | Roughly twice the round-trip time | Checkout and M-Pesa confirmation screens feel slow when every request crosses continents. |
| Data protection | Data stays in Africa | Data leaves the continent | Kenya's Data Protection Act (2019) places conditions on moving personal data abroad; staying closer keeps compliance simpler. |
| Price | Somewhat higher than eu-west-1 | Cheapest | We accept a modest cost premium for latency and data locality. |
| Service availability | All the services we use (ECS Fargate, RDS, ALB, S3, Secrets Manager) | Everything | No service we need is missing. |

There is no AWS region inside Kenya, so Cape Town is the closest full region that offers everything we need. af-south-1 is an opt-in region, so it has to be enabled on the account before use.

## Multi-AZ: why two Availability Zones

An Availability Zone is one or more data centres with independent power, cooling and networking, a few kilometres from the other AZs in the region, and connected to them by low-latency links. A single AZ can fail (power, flooding, network cut). A **region-wide** failure is much rarer.

We run every tier in **two AZs** (`af-south-1a` and `af-south-1b`):

| Tier | AZ a | AZ b | What happens if AZ a fails |
|---|---|---|---|
| Load balancer | ALB node | ALB node | The ALB stops sending traffic to AZ a; customers are served from AZ b. |
| App (ECS Fargate) | ≥1 task | ≥1 task | ECS replaces the lost tasks in AZ b. We run enough tasks that **one AZ can carry full load** (N+1). |
| Database (RDS Multi-AZ) | Primary | Synchronous standby | RDS fails over to the standby, typically in one to two minutes, with no committed transactions lost thanks to synchronous replication. |

**Reliability reasoning:**
- No single point of failure: every tier has a copy in the other AZ.
- **Synchronous** database replication matters for a payments platform. An asynchronous replica could lose the last few seconds of payments during a failover.
- Health checks (ALB on the app, RDS on the database) make failover automatic, with no human on call needed to start it.

**Why two AZs and not three?** Two AZs survive the loss of one AZ, which is the failure we design for, at the lowest cost. af-south-1 has three AZs, so adding a third is a configuration change when traffic grows. It would also let us run at two-thirds capacity per AZ instead of needing full capacity in each.

## What this design does **not** cover

A full regional outage of af-south-1. For that we would keep encrypted database snapshots and S3 backups copied to a second region (e.g. eu-west-1), with a written restore runbook. That is a recovery plan measured in hours, which is acceptable at launch. Active-active multi-region is not justified until the business can quantify the cost of a regional outage.
