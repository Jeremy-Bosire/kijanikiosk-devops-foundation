# Hardening Decisions: KijaniKiosk Staging Pipeline

**Prepared for:** Nia
**Prepared by:** DevOps Engineering
**Date:** October 2026

## What changed this week

Last week one engineer secured our server by running a script by hand. This week that standard became two written specifications any engineer can run. The first describes the servers: three of them (customer-facing API, payments and log collection), built from one shared blueprint. The second describes how each must be set up: who may log in, what runs, what each program may touch, and how long records are kept.

One script runs both in order and passes the server addresses between them automatically. We ran it twice; the second time both tools reported nothing to change. That proves the environment is a repeatable system, not a one-off setup.

## Controls

| Control | What it does | Risk mitigated |
| :--- | :--- | :--- |
| Firewall closed from first boot (our stand-in for a cloud security group) | Each server switches its firewall on before anyone connects. Remote administration is accepted only from our private networks, never the open internet. | An attacker reaches a new server in the minutes before it is configured. |
| Key-only logins | Only one named administrator holding our private key may log in; passwords and direct "root" logins are off. The pipeline stops if the two tools disagree about which key is in use. | Password guessing; one stolen password gives full control. |
| Shared record kept off laptops | The record of what exists is kept in central storage with every previous version retained. | A lost laptop or a bad edit wipes our knowledge of the environment. |
| One change at a time (state locking) | A second person starting a change while another is running is refused. | Two overlapping changes corrupt the record or build duplicate servers. |
| No passwords in the code | Storage passwords come from the operator's session and are never saved with the code. | Credentials leaking through the code repository. |
| Payments sealed inside its own sandbox | The payments program cannot gain new powers, sees the system as read-only, gets no administrator abilities and is limited to approved system calls. | A flaw in payments code becomes a takeover of the server. |
| Payments network allow-list | Inside the server itself, payments may only talk to itself and to the API server. | A compromised payments process reaching other systems. |
| Configuration readable but not changeable | Payments can read its settings but cannot alter them, and only staff in the application group can read them at all. | Tampering with payment settings while the service runs. |
| Writable area limited to logs | The only place a service may write is the shared log folder. | Malicious code planting files elsewhere on the server. |
| Records survive restarts, and are capped | System records persist across reboots with a size limit. Application logs rotate daily and are kept for a week. | Losing evidence after an incident, or a full disk taking the service down. |

## Three decisions worth repeating to the board

**Payments is the most protected service.** Our security analysis tool rates each service from 0 (fully contained) to 10 (fully exposed). Payments started at 9.6 before Week 3 and finished Week 3 at 2.3. It now scores **1.0**, against a target of below 2.5. The gain came from rules we could not use last week, because the planned payments program needed a kind of memory access they forbid. Today's stand-in program does not; if the real one does, the score will rise and we will re-measure before go-live. The API and log services score 4.4. They are hardened, but deliberately less tightly than payments.

**Settings sit where payments can read them but not rewrite them.** The strictest sandbox setting makes almost the whole server read-only for payments. We kept its settings in the application folder, marked them read-only, and gave the program one writable place: the log folder. Every pipeline run checks that payments can read its settings and write its log.

**The shared record lives in central storage, with a known limitation.** The brief expected our local storage to offer no "one change at a time" protection. We switched on a newer locking feature, started two changes at once, and saw the second refused. It is still lab-grade. The storage runs as a single container on one laptop with a default password, and an abandoned lock must be cleared by hand. In production the same protection comes from managed services: a lock table on AWS, built-in locking in Google Cloud Storage, or Consul for a vendor-neutral setup.

## Evidence

Payments security score, as reported by the second pipeline run:

```
kk-payments (strict profile) systemd-analyze security exposure = 1.0
→ Overall exposure level for kk-payments.service: 1.0 OK
```

## What this posture does not protect against

Everything still depends on one private key on one laptop, with no second factor, so whoever holds that laptop holds every server. The settings files contain configuration but not real payment-provider credentials. When those credentials arrive, they need a proper secrets vault rather than a file. Traffic between our three servers is not encrypted, administrative access is trusted from any of our private networks rather than named machines, and logs are not yet copied off-site, so an attacker who controls a server could edit its history. When a server is rebuilt, we accept its new identity the first time we see it, which leaves a brief window for impersonation. Finally, these controls limit the damage a flaw can do. They do not find flaws in our own code, and they do not survive the failure of the single machine everything runs on.
