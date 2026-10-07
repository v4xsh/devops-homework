terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.80"
    }
  }

  # State: local by default for the lab. For a team, enable the S3 backend (bucket created by s3.tf
  # in a bootstrap run) with:  terraform init -backend-config=backend.hcl
  # backend "s3" {}
}
