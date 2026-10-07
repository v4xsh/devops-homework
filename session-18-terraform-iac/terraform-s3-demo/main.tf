# S3 bucket with versioning, default encryption and a public access block.

resource "aws_s3_bucket" "demo" {
  bucket        = var.bucket_name
  force_destroy = true # lets `terraform destroy` delete a non-empty demo bucket

  tags = {
    Name        = var.bucket_name
    Owner       = var.owner
    Environment = var.environment
    RollNo      = "10099"
    Session     = "18"
  }
}

# Keep every version of every object (protects against overwrite / delete).
resource "aws_s3_bucket_versioning" "demo" {
  bucket = aws_s3_bucket.demo.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Encrypt every new object at rest with S3-managed keys (SSE-S3 / AES-256).
resource "aws_s3_bucket_server_side_encryption_configuration" "demo" {
  bucket = aws_s3_bucket.demo.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# Block every form of public access (ACLs and bucket policies).
resource "aws_s3_bucket_public_access_block" "demo" {
  bucket = aws_s3_bucket.demo.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
