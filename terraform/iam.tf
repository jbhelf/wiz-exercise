########################################
# iam.tf
#
# Define IAM roles, policies, and instance profiles for:
# 1) EC2 Mongo VM → write backups to S3 and push logs to CloudWatch
# 2) EKS control plane (cluster role)
# 3) EKS worker nodes (node role)
########################################

#############################################################################
# 1) IAM Role & Policy for the MongoDB EC2 instance to write to S3 & CloudWatch
#############################################################################

# a) EC2 assume-role policy document
data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

# b) Create the IAM Role for EC2
resource "aws_iam_role" "mongo_ec2_role" {
  name               = "${var.name_prefix}-mongo-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
  tags = {
    Name = "${var.name_prefix}-mongo-ec2-role"
  }
}

# c) Policy document: allow S3 write (PutObject, ListBucket) and CloudWatch Logs (CreateLogGroup, CreateLogStream, PutLogEvents)
data "aws_iam_policy_document" "mongo_s3_cloudwatch" {
  statement {
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:ListBucket",
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["*"]
  }
}

# d) Create the above IAM Policy
resource "aws_iam_policy" "mongo_s3_cloudwatch_policy" {
  name        = "${var.name_prefix}-mongo-s3-cw-policy"
  description = "Allow Mongo EC2 to write to S3 and CloudWatch Logs"
  policy      = data.aws_iam_policy_document.mongo_s3_cloudwatch.json
  tags = {
    Name = "${var.name_prefix}-mongo-s3-cw-policy"
  }
}

# e) Attach the policy to the EC2 role
resource "aws_iam_role_policy_attachment" "mongo_s3_cloudwatch_attach" {
  role       = aws_iam_role.mongo_ec2_role.name
  policy_arn = aws_iam_policy.mongo_s3_cloudwatch_policy.arn
}

# f) Create an Instance Profile for EC2 to use
resource "aws_iam_instance_profile" "mongo_instance_profile" {
  name = "${var.name_prefix}-mongo-instance-profile"
  role = aws_iam_role.mongo_ec2_role.name
}


#############################################
# 2) IAM Role for the EKS control plane
#############################################

# a) EKS assume-role policy document (allows EKS service to assume this role)
data "aws_iam_policy_document" "eks_cluster_assume" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

# b) Create the EKS Cluster IAM Role
resource "aws_iam_role" "eks_cluster_role" {
  name               = "${var.name_prefix}-eks-cluster-role"
  assume_role_policy = data.aws_iam_policy_document.eks_cluster_assume.json
  tags = {
    Name = "${var.name_prefix}-eks-cluster-role"
  }
}

# c) Attach AWS managed policies required by EKS control plane
resource "aws_iam_role_policy_attachment" "eks_cluster_AmazonEKSClusterPolicy" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role_policy_attachment" "eks_cluster_AmazonEKSServicePolicy" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
}


##################################################
# 3) IAM Role for EKS worker nodes (EC2 instances)
##################################################

# a) Assume-role policy document for EC2 (same as above for EC2)
data "aws_iam_policy_document" "eks_node_assume" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

# b) Create the EKS NodeGroup IAM Role
resource "aws_iam_role" "eks_node_role" {
  name               = "${var.name_prefix}-eks-node-role"
  assume_role_policy = data.aws_iam_policy_document.eks_node_assume.json
  tags = {
    Name = "${var.name_prefix}-eks-node-role"
  }
}

# c) Attach AWS managed policies required by EKS nodes
resource "aws_iam_role_policy_attachment" "eks_node_AmazonEKSWorkerNodePolicy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "eks_node_AmazonEKS_CNI_Policy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "eks_node_AmazonEC2ContainerRegistryReadOnly" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}