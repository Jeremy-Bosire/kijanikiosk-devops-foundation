# Remote state: MinIO (S3-compatible) running locally in Docker.
#
# Backend blocks cannot use variables, so these values are fixed here and
# credentials come from the environment (AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY),
# which pipeline.sh exports. Nothing secret is committed.
#
# Locking: use_lockfile = true makes Terraform write a terraform.tfstate.tflock
# object using an S3 conditional write (If-None-Match). MinIO honours conditional
# writes, so a second concurrent plan/apply is refused. This is NOT the same
# guarantee as DynamoDB/GCS/Consul locking - see hardening-decisions.md.
terraform {
  backend "s3" {
    bucket = "kijanikiosk-tfstate"
    key    = "terraform.tfstate"
    region = "us-east-1" # ignored by MinIO, required by the S3 backend

    endpoints = {
      s3 = "http://localhost:9000"
    }

    use_path_style              = true
    use_lockfile                = true
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_s3_checksum            = true
  }
}
