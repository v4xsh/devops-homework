# One provider block for both targets:
#   * real AWS           -> use_localstack = false (credentials from the environment / SSO profile)
#   * LocalStack (local) -> use_localstack = true  (fake credentials, every API pointed at localhost:4566)
locals {
  ls = var.use_localstack ? var.localstack_endpoint : null
}

provider "aws" {
  region = var.aws_region

  access_key                  = var.use_localstack ? "test" : null
  secret_key                  = var.use_localstack ? "test" : null
  skip_credentials_validation = var.use_localstack
  skip_metadata_api_check     = var.use_localstack
  skip_requesting_account_id  = var.use_localstack
  s3_use_path_style           = var.use_localstack

  endpoints {
    ec2 = local.ls
    eks = local.ls
    ecr = local.ls
    iam = local.ls
    kms = local.ls
    s3  = local.ls
    sts = local.ls
  }

  default_tags {
    tags = {
      Project   = var.project
      Owner     = "vansh-dobhal-10099" # S3 tag values may not contain "(" or ")"
      ManagedBy = "terraform"
      Env       = var.environment
    }
  }
}
