# IAM Least Privilege: Payments Receipt Service

## The task

After a successful M-Pesa payment, the **payments service** (an ECS Fargate task) must:
1. Read the M-Pesa Daraja API credentials from AWS Secrets Manager.
2. Save a PDF receipt to S3 under `receipts/`, encrypted with our KMS key.
3. Read a receipt back when a customer re-downloads it.

That is everything it needs to do. The role below grants exactly that, and nothing more.

## Role: `kk-payments-receipts-role`

**Trust policy:** who can use the role. Only ECS tasks in our own account:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": { "Service": "ecs-tasks.amazonaws.com" },
      "Action": "sts:AssumeRole",
      "Condition": {
        "StringEquals": { "aws:SourceAccount": "111122223333" }
      }
    }
  ]
}
```

**Permissions policy:** what the role can do:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ReadOnlyTheMpesaSecret",
      "Effect": "Allow",
      "Action": "secretsmanager:GetSecretValue",
      "Resource": "arn:aws:secretsmanager:af-south-1:111122223333:secret:prod/payments/mpesa-daraja-*"
    },
    {
      "Sid": "WriteAndReadReceiptsOnly",
      "Effect": "Allow",
      "Action": ["s3:PutObject", "s3:GetObject"],
      "Resource": "arn:aws:s3:::kijanikiosk-receipts-prod/receipts/*"
    },
    {
      "Sid": "UseOnlyTheReceiptsKeyViaS3AndSecretsManager",
      "Effect": "Allow",
      "Action": ["kms:Decrypt", "kms:GenerateDataKey"],
      "Resource": "arn:aws:kms:af-south-1:111122223333:key/1a2b3c4d-5e6f-7a8b-9c0d-1e2f3a4b5c6d",
      "Condition": {
        "StringEquals": {
          "kms:ViaService": [
            "s3.af-south-1.amazonaws.com",
            "secretsmanager.af-south-1.amazonaws.com"
          ]
        }
      }
    },
    {
      "Sid": "DenyUnencryptedReceiptUploads",
      "Effect": "Deny",
      "Action": "s3:PutObject",
      "Resource": "arn:aws:s3:::kijanikiosk-receipts-prod/receipts/*",
      "Condition": {
        "StringNotEquals": { "s3:x-amz-server-side-encryption": "aws:kms" }
      }
    },
    {
      "Sid": "DenyAnyRequestNotOverTLS",
      "Effect": "Deny",
      "Action": "*",
      "Resource": "*",
      "Condition": { "Bool": { "aws:SecureTransport": "false" } }
    }
  ]
}
```

(`111122223333` and the key ID are placeholders for the real account and KMS key.)

## Why each choice is least privilege

| Decision | Instead of | Effect |
|---|---|---|
| One secret, by name prefix (`mpesa-daraja-*`; the `-*` covers the random suffix AWS adds) | `secretsmanager:*` on `*` | The service cannot read the database password or any other team's secrets. |
| Only `PutObject` + `GetObject` | `s3:*` | It cannot **delete** or overwrite-by-listing receipts, change bucket policy, or make the bucket public. |
| Only the `receipts/` prefix of one bucket | `arn:aws:s3:::*` | Exports, backups and other buckets are out of reach. |
| No `s3:ListBucket` | Allowing list | The service always knows the exact receipt key, so it never needs to enumerate other customers' receipts. |
| KMS key usable **only via** S3 and Secrets Manager | `kms:Decrypt` anywhere | Stolen credentials cannot call KMS directly to decrypt arbitrary data. |
| Explicit **Deny** on unencrypted uploads and non-TLS requests | Trusting the code | Even a bug in our code cannot store a receipt unencrypted or send data in clear text. An explicit Deny overrides any Allow. |
| Trust limited to ECS tasks in our account | Any principal | A person or another service cannot assume this role. |

## What the service **cannot** do (by design)

Delete receipts · list the bucket · read other secrets (e.g. the DB password) · touch other buckets · create users or change IAM · use the KMS key outside S3/Secrets Manager.
**If the payments container is compromised**, the attacker can read the M-Pesa secret and write or read receipts under exact keys. That damage is limited and auditable in CloudTrail, compared with full account access.

## How we keep it least privilege over time

- New permissions are added only through a pull request that names the task needing them.
- IAM Access Analyzer reviews unused permissions every quarter; anything unused for 90 days is removed.
- Database access uses a separate role and database user; this role never gets it.
