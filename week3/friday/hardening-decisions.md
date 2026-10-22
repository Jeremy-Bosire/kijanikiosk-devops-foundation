# Executive Security Hardening & Architecture Report

**Prepared for:** Nia, Chief Operating Officer & System Leadership  
**Prepared by:** DevOps & Infrastructure Engineering Team  
**Subject:** Production Baseline Security Hardening & Risk Trade-off Analysis  
**Date:** September 29, 2026  

---

## 1. Executive Summary

As KijaniKiosk expands operations across multiple kiosk locations, securing our backend infrastructure while maintaining system reliability is critical. Over the past week, engineering completed a comprehensive security overhaul of our production server environment. 

Our primary focus was securing the financial transaction processor (`kk-payments`), which handles sensitive payment payloads across port 3001. Using automated security analysis tools (`systemd-analyze security`), we successfully reduced the payment system's attack surface score from an unsafe **9.6 out of 10** down to a hardened **2.3 out of 10**—representing a **76% reduction in security exposure**.

Crucially, this hardening was achieved without interrupting live kiosk payment processing, breaking automated daily log audits, or causing system downtime.

---

## 2. Hardening Decision & Impact Matrix

The following table summarizes the security controls implemented, the technical protections they enforce, and their direct business impact on kiosk operations:

| Security Control | Protection Enforced | Business & Operational Impact | Risk Level Mitigated |
| :--- | :--- | :--- | :--- |
| **Process Privilege Freeze** (`NoNewPrivileges`) | Prevents running software from tricking the system into granting higher administrative rights. | Ensures a compromised application cannot gain full server control. | Critical |
| **System File Lock** (`ProtectSystem=strict`) | Locks the entire server filesystem into read-only mode for the payment application. | Prevents malicious code or attackers from modifying server configuration files or software. | High |
| **User Directory Isolation** (`ProtectHome`) | Blocks the application from viewing or touching user directories (`/home`, `/root`). | Protects administrative files and credentials from unauthorized exposure. | Medium |
| **Temporary Workspace Isolation** (`PrivateTmp`) | Provides a private, temporary scratch area unique to each running service. | Prevents independent applications from snooping on or tampering with each other's temporary files. | Medium |
| **Hardware Device Lockdown** (`PrivateDevices`) | Denies application access to physical storage drives and system hardware components. | Prevents rogue software from reading raw hard drive sectors or manipulating server hardware. | High |
| **Administrative Power Revocation** (`CapabilityBoundingSet`) | Strips away standard Linux system administration privileges from application tasks. | Ensures software can only perform its designated job and cannot alter network interfaces or system time. | Critical |
| **Network Protocol Boundary** (`RestrictAddressFamilies`) | Limits networking capabilities strictly to standard web and internet communication channels. | Blocks unauthorized low-level network manipulation while allowing legitimate payment gateway calls. | Medium |
| **Configuration Guard** (`ReadOnlyPaths`) | Explicitly locks payment configuration files (`payments-api.env`) during operation. | Guarantees that payment API keys and backend settings cannot be tampered with while running. | High |
| **Audit Log Access Punch-Hole** (`ReadWritePaths`) | Grants explicit write access solely to the dedicated shared log folder (`/opt/kijanikiosk/shared/logs`). | Maintains continuous audit log records required for financial compliance and troubleshooting. | High |

---

## 3. Executive Trade-off Analysis & Key Decisions

Security engineering always involves balancing protection against operational usability. Below are three key architectural trade-offs resolved during this hardening phase:

### A. Isolated System Files vs. Application Logging
* **The Challenge:** To lock down the payment system, we applied strict read-only protection across the server. However, the payment application must continuously record log entries to support financial audits and error tracking.
* **The Resolution:** Rather than weakening server protection to leave entire directories open, we created an explicit "punch-hole" rule (`ReadWritePaths`). This isolates the application to a single shared logging folder while keeping the rest of the server strictly read-only.

### B. Network Lockdown vs. Third-Party Payment Gateways
* **The Challenge:** Standard high-security templates often completely sever network capabilities for internal background tasks (`PrivateNetwork=yes`).
* **The Resolution:** Completely severing network access would prevent our payment engine from communicating with external banking and mobile money gateways. We rejected complete network isolation and instead implemented protocol filtering (`RestrictAddressFamilies`), restricting the payment service to standard web communications.

### C. Automatic User Assignment vs. Shared Group Permissions
* **The Challenge:** Automated tools suggested using transient, dynamic system accounts (`DynamicUser=yes`) that reset permissions on every restart.
* **The Resolution:** Dynamic accounts break file ownership consistency across shared system services. We opted for static, unprivileged service accounts operating under a shared group (`kijanikiosk`). This ensures our central monitoring and logging services (`kk-logs`) can consistently review payment activity without administrative intervention.

---

## 4. Known Operational Gaps & Future Roadmap

While the local server environment is now secure, engineering has identified four structural limitations that should be addressed in upcoming infrastructure updates:

1. **Hardcoded Subnet Firewall Rules:** Current firewall rules strictly permit external administrative access from a single static subnet (`10.0.1.0/24`). If our management network changes or expands to secondary cloud regions, firewall configuration scripts will require manual updates.
2. **Single-Host Centralization:** All application services (`kk-api`, `kk-payments`, `kk-logs`) run on a single physical host. A hardware failure or physical host outage affects all services simultaneously.
3. **Local Log Storage Boundaries:** Application logs are compressed and rotated locally on the server. While rotation is functioning properly, logs should eventually be streamed in real time to an off-site central logging server (SIEM) for long-term retention and centralized threat analysis.
4. **Lack of Automated Container Orchestration:** Hardening is currently enforced via operating system configurations (`systemd`). Transitioning to containerized deployments (e.g., Docker/Kubernetes) in future phases will provide even stricter isolation across multi-kiosk environments.
