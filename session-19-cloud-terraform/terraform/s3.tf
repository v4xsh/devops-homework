# Storage layer: private, versioned, encrypted bucket for logs and artifacts.

resource "aws_s3_bucket" "artifacts" {
  bucket        = var.bucket_name
  force_destroy = true # demo bucket: allow destroy even when it holds objects

  tags = { Name = var.bucket_name, Purpose = "logs-and-artifacts" }
}

resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket                  = aws_s3_bucket.artifacts.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Store the exact bootstrap script the instance received, as a deploy artifact.
resource "aws_s3_object" "user_data_artifact" {
  bucket       = aws_s3_bucket.artifacts.id
  key          = "artifacts/${aws_instance.web.id}/user_data.sh" # implicit dependency on the instance
  content      = local.user_data
  content_type = "text/x-shellscript"
}
