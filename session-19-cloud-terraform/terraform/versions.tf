terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      # 6.x below 6.23.0: with 6.23.0+ LocalStack 4.9 community does not store
      # S3 bucket tags (tested: GetBucketTagging -> NoSuchTagSet). 6.0 - 6.22
      # work on both real AWS and LocalStack.
      version = "~> 6.0, < 6.23.0"
    }
  }
}
