# ---------------------------------------------------------------------------
# Terraform settings + AWS provider
#
# The SAME code runs against real AWS and against LocalStack (local AWS
# emulator). The switch is the boolean variable `use_localstack`:
#   use_localstack = false  -> normal AWS provider, real credentials from the
#                              environment / ~/.aws (default)
#   use_localstack = true   -> dummy "test" credentials, every service endpoint
#                              pointed at http://localhost:4566, path-style S3
# ---------------------------------------------------------------------------
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      # Any 6.x release below 6.23.0. Tested: with v6.23.0+ the bucket is created
      # on LocalStack 4.9 community but its tags are not stored (GetBucketTagging
      # -> NoSuchTagSet; newer providers change how bucket tags are sent).
      # v6.0 - v6.22 tag buckets correctly on both real AWS and LocalStack.
      version = "~> 6.0, < 6.23.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  # Only set when talking to LocalStack; null = use the normal credential chain.
  access_key = var.use_localstack ? "test" : null
  secret_key = var.use_localstack ? "test" : null

  skip_credentials_validation = var.use_localstack
  skip_requesting_account_id  = var.use_localstack
  skip_metadata_api_check     = var.use_localstack
  s3_use_path_style           = var.use_localstack

  # One `endpoints` block is generated only when use_localstack = true.
  dynamic "endpoints" {
    for_each = var.use_localstack ? [var.localstack_endpoint] : []
    content {
      s3  = endpoints.value
      sts = endpoints.value
      iam = endpoints.value
    }
  }

  # Tags added to every resource this provider creates.
  default_tags {
    tags = {
      ManagedBy = "Terraform"
      Project   = "session-18-terraform-iac"
    }
  }
}
