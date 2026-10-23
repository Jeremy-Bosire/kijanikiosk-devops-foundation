
## Evidence

| Proof | File |
| :--- | :--- |
| Run 1: Terraform apply + Ansible configure (all hosts `failed=0`) | [`pipeline-run1.log`](pipeline-run1.log) · ![](screenshots/01-run1-recap.png) |
| State survived between runs in MinIO (Challenge E) | ![](screenshots/02-minio-state.png) |
| Run 2: Terraform `No changes` | [`pipeline-run2.log`](pipeline-run2.log) · ![](screenshots/03-run2-terraform-nochanges.png) |
| Run 2: Ansible `changed=0` on every host | ![](screenshots/04-run2-recap.png) |
| Inventory generated from live IPs | ![](screenshots/05-inventory-vs-multipass.png) |
| kk-payments `systemd-analyze security` = 1.0 (< 2.5) | ![](screenshots/06-payments-score.png) |
| Clean teardown | [`destroy-output.txt`](destroy-output.txt) · ![](screenshots/07-destroy.png) |
| Failure handling: an earlier run stopped with a non-zero exit when one host timed out | [`pipeline-run1-failed-attempt.log`](pipeline-run1-failed-attempt.log) |
