########################################
# variables.tf
# Define reusable inputs for AWS setup.
########################################

# 1) AWS region to deploy into
variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-west-2"
}

# 2) VPC CIDR block
variable "vpc_cidr" {
  description = "CIDR block for the main VPC"
  type        = string
  default     = "10.0.0.0/16"
}

# 3) Public subnet CIDR (Mongo VM)
variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet (Mongo VM)"
  type        = string
  default     = "10.0.1.0/24"
}

# 4) Private subnet CIDR (EKS nodes)
variable "private_subnet_cidr" {
  description = "CIDR block for the private subnet (EKS nodes)"
  type        = string
  default     = "10.0.2.0/24"
}

# 5) EC2 instance type for Mongo VM
variable "mongo_instance_type" {
  description = "EC2 instance type for MongoDB VM"
  type        = string
  default     = "t2.micro"
}

# 6) EKS worker node instance type
variable "eks_node_type" {
  description = "Instance type for EKS worker nodes"
  type        = string
  default     = "t3.small"
}

# 7) Key pair name for SSH access to EC2
#    This must match an existing AWS key-pair in us-west-2 (e.g. "my-aws-key").
variable "ssh_key_name" {
  description = "Name of an existing AWS key pair for EC2 SSH (not the private key itself)"
  type        = string
  default     = "wiz-exercise"
}

# 8) CIDR allowed to SSH into Mongo VM (broad by design)
variable "ssh_allowed_cidr" {
  description = "CIDR block permitted to SSH to Mongo VM (e.g. 0.0.0.0/0)"
  type        = string
  default     = "0.0.0.0/0"
}

# 9) Prefix for naming all resources
variable "name_prefix" {
  description = "Prefix for AWS resource names"
  type        = string
  default     = "wizex"
}

variable "private_subnet_cidr_2" {
  description = "CIDR block for second private subnet (EKS nodes)"
  type        = string
  default     = "10.0.3.0/24"
}