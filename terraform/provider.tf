########################################
# provider.tf
# Configure Terraform to use AWS
########################################

terraform {
  required_version = ">= 1.2.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  # AWS credentials (Access Key ID and Secret Access Key) are read from:
  # 1) Environment variables (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY), or
  # 2) AWS CLI configuration (~/.aws/credentials), or
  # 3) An attached IAM role if running in AWS. 
}