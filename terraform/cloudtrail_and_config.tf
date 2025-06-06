########################################
# cloudtrail_and_config.tf
#
# 1) Create S3 bucket for CloudTrail logs              (with SSE)
# 2) Bucket policy allowing CloudTrail to write logs
# 3) Create CloudWatch Log Group & IAM Role for CloudTrail
# 4) Create CloudTrail trail delivering logs to S3 AND CW Logs
# 5) Create S3 bucket for AWS Config snapshot/history  (with SSE)
# 6) Bucket policy allowing AWS Config to write to bucket
# 7) IAM Role & Inline Policy for AWS Config
# 8) AWS Config Recorder & Delivery Channel
########################################

# --------------------------------------
# 1) S3 bucket for CloudTrail logs
# --------------------------------------
resource "aws_s3_bucket" "cloudtrail_logs" {
  bucket = "${var.name_prefix}-cloudtrail-logs"

  tags = {
    Name = "${var.name_prefix}-cloudtrail-logs"
  }
}

# 1b) SSE configuration (moved out of inline to separate resource)
resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail_logs_sse" {
  bucket = aws_s3_bucket.cloudtrail_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# 1c) Block public access on CloudTrail bucket
resource "aws_s3_bucket_public_access_block" "cloudtrail_logs_pab" {
  bucket = aws_s3_bucket.cloudtrail_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# --------------------------------------
# 2) Bucket Policy to Allow CloudTrail to Write
# --------------------------------------
data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "cloudtrail_bucket_policy" {
  statement {
    sid    = "AWSCloudTrailAclCheck"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    actions   = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.cloudtrail_logs.arn]
  }

  statement {
    sid    = "AWSCloudTrailWrite"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    actions = ["s3:PutObject"]
    resources = [
      "${aws_s3_bucket.cloudtrail_logs.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
    ]
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }
}

resource "aws_s3_bucket_policy" "cloudtrail_logs_policy" {
  bucket = aws_s3_bucket.cloudtrail_logs.id
  policy = data.aws_iam_policy_document.cloudtrail_bucket_policy.json
}

# --------------------------------------
# 3) CloudWatch Log Group & IAM Role for CloudTrail
# --------------------------------------
resource "aws_cloudwatch_log_group" "cloudtrail" {
  name              = "/aws/cloudtrail/${var.name_prefix}-trail"
  retention_in_days = 90

  tags = {
    Name = "${var.name_prefix}-cloudtrail-logs-group"
  }
}

data "aws_iam_policy_document" "cloudtrail_cwlogs_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cloudtrail_cwlogs_role" {
  name               = "${var.name_prefix}-ct-cwlogs-role"
  assume_role_policy = data.aws_iam_policy_document.cloudtrail_cwlogs_assume.json
}

# Inline policy so CloudTrail can CreateLogGroup, CreateLogStream, and PutLogEvents
resource "aws_iam_role_policy" "cloudtrail_cwlogs_inline" {
  name = "${var.name_prefix}-ct-cwlogs-inline"
  role = aws_iam_role.cloudtrail_cwlogs_role.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowCloudTrailToCreateLogGroup",
      "Effect": "Allow",
      "Action": "logs:CreateLogGroup",
      "Resource": "arn:aws:logs:*:*:*"
    },
    {
      "Sid": "AllowCloudTrailToCreateLogStream",
      "Effect": "Allow",
      "Action": "logs:CreateLogStream",
      "Resource": "arn:aws:logs:*:*:log-group:/aws/cloudtrail/${var.name_prefix}-trail:*"
    },
    {
      "Sid": "AllowCloudTrailToPutLogEvents",
      "Effect": "Allow",
      "Action": "logs:PutLogEvents",
      "Resource": "arn:aws:logs:*:*:log-group:/aws/cloudtrail/${var.name_prefix}-trail:*:*"
    }
  ]
}
EOF
}

# --------------------------------------
# 4) CloudTrail trail writing to both S3 and CW Logs
# --------------------------------------
resource "aws_cloudtrail" "this" {
  name                          = "${var.name_prefix}-trail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail_logs.bucket
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true

  cloud_watch_logs_group_arn = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
  cloud_watch_logs_role_arn  = aws_iam_role.cloudtrail_cwlogs_role.arn

  event_selector {
    read_write_type           = "All"
    include_management_events = true
    data_resource {
      type   = "AWS::S3::Object"
      values = ["arn:aws:s3:::"]
    }
  }

  tags = {
    Name = "${var.name_prefix}-cloudtrail"
  }

  depends_on = [
    aws_s3_bucket_policy.cloudtrail_logs_policy,
    aws_iam_role_policy.cloudtrail_cwlogs_inline,
    aws_cloudwatch_log_group.cloudtrail
  ]

  lifecycle {
    create_before_destroy = true
  }
}

# --------------------------------------
# 5) S3 bucket for AWS Config snapshots & history
# --------------------------------------
resource "aws_s3_bucket" "config_snapshot" {
  bucket = "${var.name_prefix}-config-bucket"

  tags = {
    Name = "${var.name_prefix}-config-bucket"
  }
}

# 5b) SSE configuration for AWS Config bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "config_snapshot_sse" {
  bucket = aws_s3_bucket.config_snapshot.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# 5c) Block all public access on AWS Config bucket
resource "aws_s3_bucket_public_access_block" "config_pab" {
  bucket = aws_s3_bucket.config_snapshot.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# --------------------------------------
# 6) Bucket Policy to Allow AWS Config to Write
# --------------------------------------
data "aws_iam_policy_document" "config_s3_policy" {
  statement {
    sid    = "AllowConfigToWrite"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }
    actions = [
      "s3:PutObject",
      "s3:GetBucketAcl",
      "s3:ListBucket"
    ]
    resources = [
      aws_s3_bucket.config_snapshot.arn,
      "${aws_s3_bucket.config_snapshot.arn}/*"
    ]
  }
}

resource "aws_s3_bucket_policy" "config_bucket_policy" {
  bucket = aws_s3_bucket.config_snapshot.id
  policy = data.aws_iam_policy_document.config_s3_policy.json
}

# --------------------------------------
# 7) IAM Role & Inline Policy for AWS Config
# --------------------------------------
data "aws_iam_policy_document" "config_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "config_role" {
  name               = "${var.name_prefix}-config-role"
  assume_role_policy = data.aws_iam_policy_document.config_assume_role.json
}

resource "aws_iam_role_policy" "config_inline_policy" {
  name = "${var.name_prefix}-config-inline"
  role = aws_iam_role.config_role.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowConfigToWriteToS3",
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetBucketAcl",
        "s3:ListBucket"
      ],
      "Resource": [
        "${aws_s3_bucket.config_snapshot.arn}",
        "${aws_s3_bucket.config_snapshot.arn}/*"
      ]
    },
    {
      "Sid": "AllowConfigDelivery",
      "Effect": "Allow",
      "Action": [
        "config:Put*",
        "config:Describe*"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

# --------------------------------------
# 8) AWS Config Recorder & Delivery Channel
# --------------------------------------
resource "aws_config_configuration_recorder" "this" {
  name     = "${var.name_prefix}-recorder"
  role_arn = aws_iam_role.config_role.arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = false
  }
}

resource "aws_config_delivery_channel" "this" {
  name           = "${var.name_prefix}-delivery"
  s3_bucket_name = aws_s3_bucket.config_snapshot.bucket

  depends_on = [
    aws_s3_bucket_policy.config_bucket_policy
  ]
}

resource "aws_config_configuration_recorder_status" "this" {
  name       = aws_config_configuration_recorder.this.name
  is_enabled = true

  depends_on = [
    aws_config_delivery_channel.this
  ]
}