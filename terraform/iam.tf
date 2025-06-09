########################################
# iam.tf
# IAM roles & policy attachments for EKS
########################################

# 1) Assume‐role for EKS control plane
data "aws_iam_policy_document" "eks_cluster_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

# 2) Assume‐role for EKS worker nodes
data "aws_iam_policy_document" "eks_node_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# 3) IAM Role for EKS control plane
resource "aws_iam_role" "eks_cluster_role" {
  name = "${var.name_prefix}-eks-cluster-role"
  assume_role_policy = data.aws_iam_policy_document.eks_cluster_assume.json
  tags = { Name = "${var.name_prefix}-eks-cluster-role" }
}

# Attach managed policies to control‐plane role
resource "aws_iam_role_policy_attachment" "eks_cluster_attach" {
  role = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role_policy_attachment" "eks_service_attach" {
  role = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
}


# 4) IAM Role for EKS worker nodes
resource "aws_iam_role" "eks_node_role" {
  name = "${var.name_prefix}-eks-node-role"
  assume_role_policy = data.aws_iam_policy_document.eks_node_assume.json
  tags = { Name = "${var.name_prefix}-eks-node-role" }
}

# Attach managed policies to worker‐node role
resource "aws_iam_role_policy_attachment" "eks_node_worker_attach" {
  role = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "eks_node_cni_attach" {
  role = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "eks_node_ecr_attach" {
  role = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

#Overly Permissive VM
data "aws_iam_policy_document" "mongo_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "mongo_vm_role" {
  name = "${var.name_prefix}-mongo-vm-role"
  assume_role_policy = data.aws_iam_policy_document.mongo_assume.json
}

resource "aws_iam_role_policy_attachment" "mongo_admin_attach" {
  role = aws_iam_role.mongo_vm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_iam_instance_profile" "mongo_vm_profile" {
  name = "${var.name_prefix}-mongo-vm-profile"
  role = aws_iam_role.mongo_vm_role.name
}

resource "aws_security_group" "mongo_sg" {
  name        = "${var.name_prefix}-mongo-sg"
  description = "Allow SSH from anywhere; Mongo only from private subnets"
  vpc_id      = aws_vpc.main.id

  # SSH from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_allowed_cidr]
  }

  # MongoDB only from your Kubernetes private subnets
  ingress {
    from_port   = 27017
    to_port     = 27017
    protocol    = "tcp"
    cidr_blocks = var.private_subnets
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_role_policy_attachment" "eks_node_ecr_read" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}