########################################
# eks_cluster.tf
#
# Provision EKS control plane & node group
# using two private subnets in different AZs.
########################################

resource "aws_eks_cluster" "this" {
  name     = "${var.name_prefix}-eks-cluster"
  role_arn = aws_iam_role.eks_cluster_role.arn

  vpc_config {
    subnet_ids = [
      aws_subnet.private.id,
      aws_subnet.private2.id
    ]
    endpoint_public_access  = true
    endpoint_private_access = false
  }

  version = "1.30"

  tags = {
    Name = "${var.name_prefix}-eks-cluster"
  }
}

resource "aws_eks_node_group" "this" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.name_prefix}-eks-nodegroup"
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids = [
    aws_subnet.private.id,
    aws_subnet.private2.id
  ]

  scaling_config {
    desired_size = 1
    max_size     = 1
    min_size     = 1
  }

  instance_types = [var.eks_node_type]

  depends_on = [
    aws_iam_role_policy_attachment.eks_node_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.eks_node_AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.eks_node_AmazonEC2ContainerRegistryReadOnly
  ]

  tags = {
    Name = "${var.name_prefix}-eks-nodegroup"
  }
}

output "eks_cluster_endpoint" {
  description = "EKS cluster endpoint for kubeconfig"
  value       = aws_eks_cluster.this.endpoint
}

output "eks_cluster_certificate_authority" {
  description = "Base64 certificate authority data for EKS cluster"
  value       = aws_eks_cluster.this.certificate_authority[0].data
}

output "eks_cluster_name" {
  description = "Name of the EKS cluster"
  value       = aws_eks_cluster.this.name
}