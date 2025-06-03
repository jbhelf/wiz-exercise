########################################
# s3.tf
#
# Create a public-read, public-list S3 bucket
# for MongoDB backups using only a bucket policy
# (no ACL resource), plus a public-access-block override.
########################################

# 1) Generate a random suffix to guarantee a unique bucket name
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# 2) Create the S3 bucket (no ACL or policy in this block)
resource "aws_s3_bucket" "mongo_backups" {
  bucket = "${var.name_prefix}-mongo-backups-${random_id.bucket_suffix.hex}"
  tags = {
    Name = "${var.name_prefix}-mongo-backups"
  }
}

# 3) Override public-access-block to allow public bucket policy
resource "aws_s3_bucket_public_access_block" "mongo_backups_pab" {
  bucket = aws_s3_bucket.mongo_backups.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# 4) Define a bucket policy that allows public ListBucket and GetObject
resource "aws_s3_bucket_policy" "mongo_backups_policy" {
  bucket = aws_s3_bucket.mongo_backups.id

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowPublicReadAndList",
      "Effect": "Allow",
      "Principal": "*",
      "Action": ["s3:GetObject","s3:ListBucket"],
      "Resource": [
        "${aws_s3_bucket.mongo_backups.arn}",
        "${aws_s3_bucket.mongo_backups.arn}/*"
      ]
    }
  ]
}
POLICY

  # Ensure the public-access-block override is applied first
  depends_on = [aws_s3_bucket_public_access_block.mongo_backups_pab]
}