# Week 5 Reflection

## 1. Two requirements in tension

The tension appeared during fault injection: **"versions are unique per commit and can never be overwritten"** versus **"re-running a build is harmless"**. I configured Nexus `npm-hosted` as `ALLOW_ONCE` so that `1.0.0-<sha>` always refers to one exact set of bytes. Then the SCM poller rebuilt commit `e75c9eb` on its own (build #3), and later a manual re-run of `0de51bf` (build #10). Both were the same commit, which meant the same version, and Nexus rejected both with `409 Conflict`. The pipeline went red even though nothing in the code was wrong.

I prioritised immutability. For a payments platform, "the version Week 7 deploys is byte-for-byte the version that passed these checks" matters more than a tidy build history, and a loud failure on a duplicate is safer than a silent overwrite. The cost is that a rebuild of an already-published commit is red, and anyone reading the dashboard has to know why. The next change I would make is a check at the start of Publish: if `npm view kijanikiosk-payments@$ARTIFACT_VERSION` already exists and its integrity hash matches the archived tarball, report "already published" and pass. That keeps immutability without false alarms.

A related lesson came from my own history. I amended my first commit after Jenkins had already built and published it. The result is `1.0.0-e2742cd`, a version in Nexus whose SHA no longer exists in git. The SHA in a version string only gives traceability if pushed history is never rewritten.

## 2. One sentence, two registers

**Board document (for Nia):**
> "Steps 3a and 3b run side by side."

**Technical (Jenkinsfile comment, or to Osei):**
> "`Verify` is a declarative `parallel` block with two branches, `Test` (`npm run test:ci`, JUnit to `reports/junit.xml`) and `Security Audit` (`npm audit --audit-level=high`), in the same `node:22.11.0-alpine3.20` container. `failFast` is left off so both branches always complete, and either failing marks the stage failed and skips Archive and Publish."

**Same in both:** the two checks happen at the same time, and both must pass before anything is packaged.
**Different:** the technical version names the tools, the threshold (high and above), where results go, and the failure semantics (no fail-fast, downstream stages skipped). Nia needs to know that it is fast and that both checks are mandatory; Osei needs to know exactly what "pass" means so he can change it safely.

## 3. Forty developers instead of four: what breaks first

**The single build queue breaks first.** Today there is one job that watches one branch, with `disableConcurrentBuilds()` on a single Jenkins controller that runs builds on its own two executors. That was correct for four people because it guarantees ordered, non-overlapping publishes. With forty developers pushing several times a day, and each run taking 1–4 minutes, commits queue behind each other. Because the job polls one branch, a developer's change is not checked until it reaches that branch, which is too late.

What needs to change:
- **A multibranch pipeline triggered by webhooks**, so every branch and pull request gets its own build and feedback arrives before merge, not after. Polling forty developers' activity every two minutes does not scale either.
- **Ephemeral build agents** (Docker cloud or Kubernetes) instead of executors on the controller. Capacity then grows with demand, and the controller only orchestrates.
- **Publish only from the main branch.** Branch builds stop at Archive, so Nexus is not flooded with forty developers' work-in-progress versions.
- **An npm proxy repository in Nexus**, so forty parallel `npm ci` runs hit a local cache instead of the public registry.
