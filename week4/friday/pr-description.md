# PR: feature/week4-iac-pipeline → develop

**Path: primary (Multipass + MinIO). Multipass runs with the qemu driver inside WSL2 on Windows 11 Home; see environment-setup.md for why.**

I built the full KijaniKiosk staging pipeline. Terraform calls one reusable `app_server` module with `for_each` to create the api, payments and logs VMs. Their IPs come back through the `multipass_instance` data source, and state lives in MinIO with S3-native locking (`use_lockfile`). `pipeline.sh` plans and applies (or skips the apply when the plan is empty), reads each VM's live IP, writes `inventory.ini`, records host keys, and checks that Terraform and Ansible agree on the SSH key and admin networks. Only then does it run a playbook that rebuilds the Week 3 standard on all three servers across the seven phases. The second run shows `No changes` and `changed=0` on every host, and both logs are attached. The decision I'm most confident about is that the playbook *proves* the hardening instead of assuming it. The verify phase asserts that kk-payments can read `payments-api.env` as its own user under `ProtectSystem=strict`, that the running service can read its config and write its log, and that `systemd-analyze security` scores it below 2.5 (it scores 1.0). If any of those regress, the pipeline fails. With more time, I'd replace raw IPs and trust-on-first-use host keys with DNS names and host keys published from cloud-init. That's the handoff I trust least (see reflection Q3).

**Reflection:** see `week4/friday/reflection.md`.

**Note for reviewers:** `minio/minio` no longer pulls from Docker Hub, because MinIO archived the community edition. `scripts/start-minio.sh` uses `cgr.dev/chainguard/minio` with a named volume and a versioned bucket instead.
