########################################
# eks_cluster.tf
# EKS control plane and managed node group
########################################

# 1) EKS cluster
resource "aws_eks_cluster" "this" {
  name     = "${var.name_prefix}-eks-cluster"
  role_arn = aws_iam_role.eks_cluster_role.arn

  vpc_config {
    subnet_ids = values(aws_subnet.private)[*].id
  }

  version = "1.30"

  tags = {
    Name = "${var.name_prefix}-eks-cluster"
  }
}

# 2) EKS managed node group
resource "aws_eks_node_group" "this" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.name_prefix}-eks-nodegroup"
  node_role_arn   = aws_iam_role.eks_node_role.arn

  subnet_ids = values(aws_subnet.private)[*].id

  scaling_config {
    desired_size = 1
    max_size     = 1
    min_size     = 1
  }

  instance_types = [var.eks_node_type]

  tags = {
    Name = "${var.name_prefix}-eks-nodegroup"
  }
}

output "eks_cluster_endpoint" {
  description = "EKS cluster API endpoint"
  value       = aws_eks_cluster.this.endpoint
}

output "eks_cluster_ca" {
  description = "Cluster CA data (base64)"
  value       = aws_eks_cluster.this.certificate_authority[0].data
}