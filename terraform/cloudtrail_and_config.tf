########################################
# cloudtrail_and_config.tf
# Single file for CloudTrail + AWS Config setup
########################################

# ASSUME ROLE DOC for Config Recorder
data "aws_iam_policy_document" "config_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }
  }
}

# IAM Role for AWS Config
resource "aws_iam_role" "config_role" {
  name               = "${var.name_prefix}-config-role"
  assume_role_policy = data.aws_iam_policy_document.config_assume.json
  tags               = { Name = "${var.name_prefix}-config-role" }
}

# Attach managed policy for Config
resource "aws_iam_role_policy_attachment" "config_attach" {
  role       = aws_iam_role.config_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSConfigRole"
}

# S3 bucket to hold CloudTrail & Config data
resource "aws_s3_bucket" "logs" {
  bucket = "${var.name_prefix}-logs"
  tags   = { Name = "${var.name_prefix}-logs" }
}

# Enable versioning on logs bucket
resource "aws_s3_bucket_versioning" "logs" {
  bucket = aws_s3_bucket.logs.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Enforce SSE on logs bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block all public access to logs bucket
resource "aws_s3_bucket_public_access_block" "logs" {
  bucket                  = aws_s3_bucket.logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# CloudTrail that writes into the logs bucket
resource "aws_cloudtrail" "this" {
  name                          = "${var.name_prefix}-trail"
  s3_bucket_name                = aws_s3_bucket.logs.id
  is_multi_region_trail         = true
  include_global_service_events = true
  enable_log_file_validation    = true

  depends_on = [aws_s3_bucket_public_access_block.logs]
}

# Config Delivery Channel pointing at same logs bucket
resource "aws_config_delivery_channel" "this" {
  name           = "${var.name_prefix}-channel"
  s3_bucket_name = aws_s3_bucket.logs.id

  depends_on = [aws_s3_bucket.logs]
}

# Config Recorder to record all supported resources
resource "aws_config_configuration_recorder" "this" {
  name     = "${var.name_prefix}-recorder"
  role_arn = aws_iam_role.config_role.arn

  recording_group {
    all_supported = true
  }
}

# Ensure recorder is active
resource "aws_config_configuration_recorder_status" "this" {
  name       = aws_config_configuration_recorder.this.name
  is_enabled = true
}