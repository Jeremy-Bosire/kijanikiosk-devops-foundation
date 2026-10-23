# DevOps Delivery Notes: Flow, Feedback and Learning

How the three DevOps principles ("The Three Ways") show up in the way this starter kit was delivered, and how the team will keep using them.

## Branching workflow used

```
main        ← production-ready; changes only arrive from develop via PR
  └── develop        ← integration branch; every feature merges here first
        └── feature/starter-kit-files   ← this work
```

1. Branched `feature/starter-kit-files` from `develop`.
2. Made small, single-purpose commits (one per document or diagram).
3. Opened a pull request into `develop` with a description of what changed and why.
4. Reviewed the PR against the submission checklist, then merged.
5. `develop` is promoted to `main` only when it is release-ready.

## Flow: work moves left to right, in small batches

- **Small batches:** each document was its own commit, so every change was easy to review and could be reverted on its own.
- **Short-lived branch:** the feature branch existed only for this task, which limits drift from `develop` and avoids painful merges.
- **Visible work:** the PR shows exactly what is in progress and what is done; nothing reaches `main` by side door.
- **Limiting work in progress:** one feature branch at a time for this kit, finished and merged before starting the next.
- **Removing constraints:** choosing PaaS (see `cloud-model.md`) removes server patching from the team's queue, so more time goes to product work.

## Feedback: find problems early, where they are cheap to fix

- **Pull request review** is the feedback gate: no change reaches `develop` without being read against the checklist (least privilege, subnet routing, AZ reasoning).
- **Design-time feedback:** writing the IAM policy exposed that the service never needs `s3:ListBucket`, a permission that is easy to grant "just in case". Catching it in review costs minutes; catching it after a breach costs customers' data.
- **Built-in feedback in the architecture:** ALB health checks and RDS failover tell the system (not a person) that an AZ is unhealthy and act on it automatically.
- **Next step:** add automated checks to the PR, such as markdown lint, a JSON validator for IAM policies, and later IAM Access Analyzer policy validation, so feedback arrives in seconds rather than at review time.

## Learning: improve the system, not just the deliverable

- **Decisions are written down with their reasons** (why af-south-1, why two AZs, why PaaS). When circumstances change, the team can revisit the reasoning instead of guessing.
- **Trade-offs are recorded honestly:** each document states what the design does *not* cover (regional outage, lock-in), so those risks are known, not discovered.
- **Blameless improvement:** when something goes wrong, the fix is a change to the system (a new check, a tighter policy) delivered through the same PR workflow, so the lesson is kept.
- **Reflection** at the end of the project (see `README.md`) captures what to improve first as the platform grows.
