# Cloud Service Model: IaaS, PaaS or SaaS?

**Decision: PaaS for the core platform, SaaS for commodity functions, and no self-managed IaaS servers at launch.**

## What KijaniKiosk needs to run

| Component | Choice | Model | Why |
|---|---|---|---|
| Web app + payments service | AWS ECS on Fargate (managed containers) | PaaS | We ship a container; AWS runs, patches and scales the hosts. |
| Database (orders, payments) | Amazon RDS for PostgreSQL, Multi-AZ | PaaS | Automated backups, patching and failover to a standby in a second AZ. |
| Load balancing + TLS | Application Load Balancer + ACM certificates | PaaS | Managed HTTPS termination and health checks across AZs. |
| Receipts / documents | Amazon S3 | PaaS (managed storage) | Durable, encrypted object storage with no servers. |
| Mobile money | M-Pesa Daraja API | SaaS | We integrate with it; we do not build payment rails. |
| Email / SMS notifications | Managed provider (e.g. Amazon SES, Africa's Talking) | SaaS | Commodity function with no competitive value in running it ourselves. |

## Why not IaaS (raw virtual machines)?

IaaS gives the most control but makes **us** responsible for OS patching, hardening, scaling, backups and failover of every server. KijaniKiosk has a small engineering team, and every hour spent patching servers is an hour not spent on the product. For a payments platform, a missed security patch is a business risk, not just an operations chore. PaaS moves that undifferentiated work to the provider under the **shared responsibility model**: AWS secures the hosts, and we secure our code, data, IAM and network rules.

## Why not SaaS for everything?

The ordering and payments logic **is** the product. No off-the-shelf e-commerce SaaS handles our M-Pesa flows, kiosk-agent model and fee rules without heavy compromise. We would also lose control over where customer data lives and how it is secured.

## Trade-offs we accept

- **Less control and some lock-in:** Fargate and RDS are AWS-specific. We reduce this by packaging the app as a standard container and using standard PostgreSQL, so a move to another provider is a migration, not a rewrite.
- **Higher unit cost than a tuned VM:** acceptable at our scale, because the alternative is an engineer's time.
- **When we would revisit:** if steady, predictable load makes reserved VMs much cheaper, or if we need OS-level control (e.g. specialised agents). That is the point to reconsider IaaS for specific workloads, not the whole platform.
