########################################
# networking.tf
#
# Define VPC, public and private subnets,
# Internet Gateway, and public route table.
########################################

# 1) Create the main VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  tags = {
    Name = "${var.name_prefix}-vpc"
  }
}

# 2) Public subnet (for Mongo VM)
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  map_public_ip_on_launch = true
  availability_zone       = "${var.aws_region}a"
  tags = {
    Name = "${var.name_prefix}-public-subnet"
  }
}

# 3) Private subnet (for EKS nodes)
#    Now assigns public IPs so node group can launch
resource "aws_subnet" "private" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.private_subnet_cidr
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true
  tags = {
    Name = "${var.name_prefix}-private-subnet"
  }
}

# 3b) Private subnet #2 (for EKS nodes)
#     Also assigns public IPs
resource "aws_subnet" "private2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.private_subnet_cidr_2
  availability_zone       = "${var.aws_region}b"
  map_public_ip_on_launch = true
  tags = {
    Name = "${var.name_prefix}-private-subnet-2"
  }
}

# 4) Internet Gateway for the VPC
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${var.name_prefix}-igw"
  }
}

# 5) Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${var.name_prefix}-public-rt"
  }
}

# 6) Route: public subnet → Internet
resource "aws_route" "public_internet_route" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

# 7) Associate the public subnet with the public route table
resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# 7b) Associate the second private subnet with the public route table (if needed)
resource "aws_route_table_association" "private2_assoc" {
  subnet_id      = aws_subnet.private2.id
  route_table_id = aws_route_table.public.id
}

# Note: We are not creating a NAT Gateway for the private subnet.
#       EKS nodes will rely on their IAM role for pulling images, and internet access isn't required for this exercise.