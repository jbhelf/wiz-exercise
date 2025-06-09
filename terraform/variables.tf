########################################
# variables.tf
# Define reusable inputs for AWS setup.
########################################

variable "aws_region" {
  description = "AWS region to deploy resources"
  type = string
  default = "us-west-2"
}

variable "name_prefix" {
  description = "Prefix for all resource names"
  type = string
  default = "wizex"
}

variable "vpc_cidr" {
  description = "CIDR block for the main VPC"
  type = string
  default = "10.0.0.0/16"
}

variable "azs" {
  description = "List of availability zones to use"
  type = list(string)
  default = ["us-west-2a", "us-west-2b"]
}

variable "public_subnets" {
  description = "CIDR blocks for public subnets"
  type = list(string)
  default = ["10.0.1.0/24"]
}

variable "private_subnets" {
  description = "CIDR blocks for private subnets"
  type = list(string)
  default = ["10.0.2.0/24", "10.0.3.0/24"]
}

variable "mongo_instance_type" {
  description = "EC2 instance type for MongoDB VM"
  type = string
  default = "t2.micro"
}

variable "eks_node_type" {
  description = "Instance type for EKS worker nodes"
  type        = string
  default     = "t3.small"
}

variable "ssh_key_name" {
  description = "Existing AWS key pair name for SSH"
  type = string
  default = "wiz-exercise"
}

variable "ssh_allowed_cidr" {
  description = "CIDR allowed to SSH into Mongo VM"
  type = string
  default = "0.0.0.0/0"
}

variable "mongo_ami" {
  description = "SSM parameter name for MongoDB AMI"
  type = string
  default = "/aws/service/canonical/ubuntu/server/bionic/stable/current/amd64/hvm/ebs-gp2/ami-id"
}

variable "ssh_private_key_path" {
  description = "Path to SSH private key for provisioning the Mongo VM"
  type        = string
}