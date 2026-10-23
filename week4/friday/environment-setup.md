# Environment Setup

**Path used: primary (Multipass + MinIO). Multipass (qemu/KVM) runs *inside* WSL2 Ubuntu on Windows 11 Home.**

This page lists the tool stack and how to rebuild it from scratch. The versions table is written by `scripts/collect-versions.sh` on the machine that produced `pipeline-run1.log` and `pipeline-run2.log`.

## Recorded versions

<!-- versions:start -->
| Tool | Version (recorded 2026-10-22 12:09 +0300) |
| :--- | :--- |
| Host OS (Windows) | Microsoft Windows [Version 10.0.26200.9457] |
| WSL | WSL version: 2.6.2.0 |
| WSL distro | Ubuntu 26.04.1 LTS / kernel 6.6.87.2-microsoft-standard-WSL2 |
| Terraform | Terraform v1.16.5 |
| Terraform multipass provider | 1.4.3 |
| Multipass | multipass   1.17.0 |
| Ansible | ansible [core 2.21.5] |
| Python (WSL) | Python 3.14.4 |
| Docker | Docker version 29.1.2, build 890dcca |
| MinIO | minio version RELEASE.2026-09-22T19-25-18Z (commit-id=df34868a88cc8c396807e04a7e220810b321bdaa) (image: cgr.dev/chainguard/minio:latest) |
| OpenSSH client | OpenSSH_10.2p1 Ubuntu-2ubuntu3.8, OpenSSL 3.5.5 27 Jan 2026 |
| Guest OS image | Ubuntu 22.04 LTS (multipass image alias "22.04") |
<!-- versions:end -->

## Topology

```
Windows 11 Home
├── Docker Desktop (WSL integration) ── minio  (S3 state backend, :9000 API, :9001 console)
└── WSL2: Ubuntu  (nested virtualisation, systemd)
    ├── terraform, ansible, pipeline.sh
    └── multipass (snap, qemu driver)
        └── kijanikiosk-api / -payments / -logs   Ubuntu 22.04, 10.25.x.x bridge
```

## Why Multipass runs inside WSL (and not the Windows Multipass)

- **Windows 11 Home has no Hyper-V.** Windows Multipass therefore uses its VirtualBox driver.
- **VirtualBox VMs aren't reachable.** Multipass puts them behind VirtualBox's NAT and reports `IPv4: N/A`. Nothing outside Multipass can reach them, so Terraform can't output a usable IP and Ansible can't SSH in.
- **Linux Multipass in WSL fixes that.** It runs with the qemu driver on nested KVM, and its VMs sit on a bridge that WSL routes to directly. Terraform, Ansible and the VMs then all live in the same Linux environment.

## One-time setup

1. **Configure WSL** in `%UserProfile%\.wslconfig`, then run `wsl --shutdown`:
   ```ini
   [wsl2]
   nestedVirtualization=true
   networkingMode=nat
   memory=5GB
   swap=4GB
   ```
   Then check from WSL:
   - `ps -p 1 -o comm=` prints `systemd`
   - `ls /dev/kvm` exists
   - `sudo usermod -aG kvm $USER` gives you access to it
2. **Install the tools (WSL):**
   ```bash
   sudo apt update && sudo apt install -y pipx python3-yaml curl unzip openssh-client git
   pipx install --include-deps ansible && pipx ensurepath
   sudo snap install multipass        # driver: qemu
   # Terraform >= 1.10 (needed for S3-native state locking) from apt.releases.hashicorp.com
   ```
   - Make sure `type -a multipass` shows `/snap/bin/multipass` first, not a wrapper for `multipass.exe`.
3. **Host firewall in WSL.** If ufw is active in the WSL distro, it drops the VMs' DHCP requests, so they launch but never get an IP and Multipass times out. Either turn it off (`sudo ufw disable`; Windows' firewall still protects the laptop) or allow Multipass's bridges:
   ```bash
   for br in mpqemubrzone1 mpqemubrzone2 mpqemubrzone3; do
     sudo ufw allow in on "$br"; sudo ufw route allow in on "$br"; sudo ufw route allow out on "$br"
   done
   ```
4. **Docker Desktop:** turn on **Settings → Resources → WSL integration** for the Ubuntu distro. Re-check with `docker version` after any `wsl --shutdown`.
5. **SSH key pair.** The name must match `ssh_key_name` in `terraform.tfvars` and `ansible_ssh_private_key_file` in `group_vars`:
   ```bash
   ssh-keygen -t ed25519 -N "" -f ~/.ssh/kijanikiosk_ed25519 -C kijanikiosk-staging
   ```
6. **MinIO state backend:**
   ```bash
   ./scripts/start-minio.sh
   ```
   - MinIO archived its community edition in late 2025, and `minio/minio` no longer pulls from Docker Hub or quay.io.
   - The script uses Chainguard's free rebuild (`cgr.dev/chainguard/minio`) and keeps its data in a named Docker volume, so state survives container restarts (Challenge E).
   - It also creates the `kijanikiosk-tfstate` bucket with versioning on.

## Sizing

The WSL VM has about 4–5 GB of RAM, shared with Docker Desktop, so the servers use the `tiny` profile (1 vCPU, 512 MB, 5 GB disk). `pipeline.sh` also applies with `-parallelism=1`, so VMs launch one at a time and no launch hits Multipass's 5-minute timeout.

## Narrowing `admin_cidrs`

The default is the three private ranges. Multipass in WSL puts the VMs on `10.25.x.0/24` (check with `multipass list`). To tighten it, put `10.25.0.0/16` in **both** `terraform/terraform.tfvars` (`admin_cidrs`) and `ansible/group_vars/kijanikiosk.yml` (`ssh_allowed_cidrs`). `pipeline.sh` refuses to run if the two differ.
