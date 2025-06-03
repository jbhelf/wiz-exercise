############################################
# security_groups.tf
#
# Define Security Groups for:
# 1) Mongo VM SSH (public → port 22 open to 0.0.0.0/0)
# 2) EKS worker nodes (node-to-node + outbound internet)
# 3) MongoDB port 27017 (only accessible from EKS nodes)
############################################

# 1) SG for Mongo VM with SSH open to the world
resource "aws_security_group" "sg_mongo_ssh" {
  name        = "${var.name_prefix}-sg-mongo-ssh"
  description = "Allow SSH from anywhere to Mongo VM"
  vpc_id      = aws_vpc.main.id

  # Ingress rule: port 22 from 0.0.0.0/0
  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_allowed_cidr]
  }

  # Allow all outbound (to update, backup scripts, etc.)
  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name_prefix}-sg-mongo-ssh"
  }
}

# 2) SG for EKS worker nodes (intra-node communication + outbound)
resource "aws_security_group" "sg_eks_nodes" {
  name        = "${var.name_prefix}-sg-eks-nodes"
  description = "Allow node-to-node traffic and all outbound"
  vpc_id      = aws_vpc.main.id

  # Ingress: allow all traffic from same SG (node-to-node)
  ingress {
    description = "Allow all node-to-node traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  # Egress: allow all outbound
  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name_prefix}-sg-eks-nodes"
  }
}

# 3) SG for MongoDB port, restricted to EKS nodes SG only
resource "aws_security_group" "sg_mongo_db" {
  name        = "${var.name_prefix}-sg-mongo-db"
  description = "Allow port 27017 only from EKS nodes"
  vpc_id      = aws_vpc.main.id

  # Ingress: Mongo port (27017) from EKS worker SG
  ingress {
    description     = "MongoDB from EKS nodes"
    from_port       = 27017
    to_port         = 27017
    protocol        = "tcp"
    security_groups = [aws_security_group.sg_eks_nodes.id]
  }

  # Egress: allow all outbound (for backups, etc.)
  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name_prefix}-sg-mongo-db"
  }
}