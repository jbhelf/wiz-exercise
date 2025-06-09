########################################
# networking.tf
# VPC, subnets, and routing configuration
########################################

# 1) Main VPC
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  enable_dns_support = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.name_prefix}-vpc"
  }
}

# 2) Internet Gateway for public subnets
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.name_prefix}-igw"
  }
}

# 3) Public subnets (one per CIDR)
resource "aws_subnet" "public" {
  for_each = toset(var.public_subnets)

  vpc_id = aws_vpc.main.id
  cidr_block = each.value
  map_public_ip_on_launch = true
  availability_zone = element(var.azs, index(var.public_subnets, each.value))

  tags = {
    Name = "${var.name_prefix}-public-${each.key}"
  }
}

# 4) Private subnets (for EKS nodes)
resource "aws_subnet" "private" {
  for_each = toset(var.private_subnets)

  vpc_id = aws_vpc.main.id
  cidr_block = each.value
  availability_zone = element(var.azs, index(var.private_subnets, each.value))

  tags = {
    Name = "${var.name_prefix}-private-${each.key}"
  }
}

# 5) Public route table and associations
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.name_prefix}-public-rt"
  }
}

resource "aws_route_table_association" "public_association" {
  for_each = aws_subnet.public
  subnet_id = each.value.id
  route_table_id = aws_route_table.public.id
}