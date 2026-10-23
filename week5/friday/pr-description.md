# PR: Week 5 – KijaniKiosk CI pipeline (board-ready)

**For Tendo:** This week I built a CI pipeline that takes every commit to `kijanikiosk-payments` through Lint → Build → a parallel Verify (Test and Security Audit) → Archive (content check + fingerprint) → Publish. It runs in a pinned `node:22.11.0-alpine3.20` container and publishes a `<semver>-<git-sha>` tarball to a Nexus npm-hosted repository. Jenkins and Nexus are defined as code in `week5/friday/ci-infra` (JCasC, Docker secrets, a scripted Nexus bootstrap). Green runs take 1–4 minutes, and Nexus holds seven distinct versions. The design decision I am most confident about is making the registry immutable: `npm-hosted` is `ALLOW_ONCE` and the publisher account can only write to that one repository. When the poller rebuilt an already-published commit, Nexus returned `409 Conflict` instead of silently replacing an artifact Week 7 might already depend on. The next thing I would add is a pre-publish check that treats "this exact version and hash is already in Nexus" as success, so rebuilding a commit is not a false red, together with webhooks and a multibranch job so feedback arrives on pull requests rather than after merge.

## Deliverables (`week5/friday/`)
| File | Contents |
|---|---|
| [`/Jenkinsfile`](../../Jenkinsfile) | Final pipeline |
| [`green-pipeline-run.txt`](green-pipeline-run.txt) | Full log of the final green run |
| [`nexus-versions-screenshot.png`](nexus-versions-screenshot.png) | Nexus showing multiple `1.0.0-<sha>` versions |
| [`fault-injection-log.md`](fault-injection-log.md) | Six faults (Lint, Build, Test, Security Audit, Archive, Publish) + evidence in `fault-evidence/` |
| [`ci-pipeline-board-document.md`](ci-pipeline-board-document.md) | Document for Nia (under 800 words) |
| [`credential-audit.txt`](credential-audit.txt) | Five credential checks against the final Jenkinsfile, git history and every build log |
| [`reflection.md`](reflection.md) | Answers to the three reflection prompts |
