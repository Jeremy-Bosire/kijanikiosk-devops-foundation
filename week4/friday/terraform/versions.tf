terraform {
  # 1.10+ is required for S3-native state locking (use_lockfile) against MinIO.
  required_version = ">= 1.10.0"

  required_providers {
    multipass = {
      source  = "larstobi/multipass"
      version = "~> 1.4.3"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

provider "multipass" {}
