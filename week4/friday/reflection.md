# Reflection: Week 4 Friday

## 1. Where two requirements conflicted

The clearest conflict was Integration Challenge D. It surfaced when I moved the Week 3 kk-payments unit into an Ansible template and pushed it to a score below 2.5. The brief calls `/opt/kijanikiosk/` "a writable path", but under `ProtectSystem=strict` it isn't: everything except `/dev`, `/proc` and `/sys` becomes read-only for the service, `/opt` included. Reading the EnvironmentFile was never the risk. systemd (PID 1) reads it before the sandbox exists, so it would load even from `/etc`. The real risk is anything the *application* does at runtime. So I made the app re-read its own config file and append to its log on every `/health` call, then had Ansible assert both. That turned "it starts" into "it can do its job inside the sandbox."

The second half of the conflict came from the score itself. Getting to 1.0 needed `PrivateUsers=yes`, which puts the service in a user namespace where only its own User and Group are mapped. The Week 3 permission model (`payments-api.env` as `root:kijanikiosk 0640`) only keeps working because `kijanikiosk` is the service's *primary* group (`Group=kijanikiosk`). If I'd given each service its own group and made `kijanikiosk` supplementary, I would have expected the read to fail in a confusing way. The Ansible task that runs `stat` as `become_user: kk-payments` is there to catch that class of regression.

A smaller conflict was idempotency against the Week 3 script. Week 3 ran `ufw --force reset` on every run, which can never report "unchanged". Moving to declarative `community.general.ufw` rules in a fixed order (allows, then the explicit deny, then default-deny and enable) kept the same final rule set and made changed=0 possible.

What I learned: a hardening score is a property of the unit *and* the workload together. Week 3 rejected `MemoryDenyWriteExecute` because Node/V8 needs JIT memory. The Python stand-in doesn't, so it's back on. The real payments app could undo that, and the score has to be re-measured when it ships.

## 2. One sentence, rewritten for Tendo

**For Nia:** "Inside the server itself, payments may only talk to itself and to the API server."

**For Tendo:** "kk-payments runs with `IPAddressDeny=any` plus `IPAddressAllow=localhost` and the kk-api address resolved from `hostvars` at template time. It's enforced by systemd's cgroup eBPF filter, so it still holds if ufw is flushed, and it re-renders (and restarts the unit) whenever the API server's IP changes."

**Lost:** Nia's version hides *how* it's enforced and *when* it changes. It also hides a consequence: the same rule blocks *outbound* traffic. When kk-payments has to call the M-Pesa Daraja API, the allow-list needs Safaricom's endpoints or an egress proxy added. The plain-English sentence sounds finished when it isn't. **Gained:** Tendo's version is testable and reviewable. It names the mechanism, the data source of the allowed IP, and the failure mode (an IP change triggers a restart). Those are exactly what an engineer needs to judge whether it's correct. Nia's version is the one that gets repeated in a board meeting; Tendo's is the one that gets verified.

## 3. The most fragile handoff

The most fragile handoff is the IP address going from Multipass/Terraform to the inventory to an SSH connection from the control node. I hit four different failures on exactly this line before the pipeline ever succeeded:

1. **The address existed but wasn't reachable.** On Windows 11 Home, Multipass falls back to VirtualBox, which reports `IPv4: N/A`: the VM sits behind VirtualBox's NAT and only Multipass's internal port-forward can reach it. Terraform would have "succeeded" and handed Ansible nothing usable. I moved Multipass inside WSL (qemu on nested KVM) so the VMs live on a bridge the control node routes to.
2. **The address never arrived.** Inside WSL, VMs launched but timed out with no IP. A packet capture showed the DHCP request reaching the bridge and no reply. My workstation's own ufw, left on by running the Week 3 script locally, was dropping DHCP before dnsmasq saw it. The provisioning tool was fine; the *control node's* firewall broke the handoff.
3. **The state backend vanished.** After `wsl --shutdown`, Docker Desktop's WSL integration hadn't come back, so `localhost:9000` timed out and `terraform init` failed before any server existed.

4. **The tool's output format changed.** Multipass 1.17 began printing `Launched: kijanikiosk-api in zone1`. The Terraform provider (last released for older Multipass) reads everything after `Launched: ` as the VM name, so all three VMs were created but Terraform recorded none of them and failed. A small shim (`scripts/bin/multipass`) trims the zone suffix. The real lesson is that a handoff that parses human-readable text is only as stable as the least-maintained tool in the chain.

None of these were bugs in my Terraform or Ansible code. They were assumptions about the environment: that a reported IP is routable, that the control node doesn't filter the VM network, and that local services are running. A slightly different production environment breaks the same way. Think of a CI runner in a different VPC, a security group that allows the office but not the runner, or a DHCP lease that changes after a reboot.

To make the handoff robust I'd need to know:

- **How addresses are assigned:** static, reserved or DHCP, and whether there's internal DNS I could target instead of raw IPs.
- **The network path:** how traffic gets from wherever the pipeline runs to the servers (direct, bastion or VPN), and which firewalls sit on that path, on *both* ends.
- **Which interface is for management** when servers have more than one NIC.
- **Whether host keys can be published out-of-band** (cloud-init to console or provider metadata), so the first SSH connection is verified, not trusted on first use.

`pipeline.sh` already turns some of these into early, explicit failures: it rejects a non-IPv4 value, keyscans with retries, and SSH-tests every host before Ansible starts. The next step would be a preflight that checks reachability and the backend *before* `terraform apply`, so a broken environment fails in seconds instead of after a 5-minute launch timeout.
