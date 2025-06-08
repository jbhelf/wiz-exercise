########################################
# mongo_backup.tf
# Create S3 bucket for MongoDB backups and the Mongo VM
########################################

# Fetch the latest Ubuntu Bionic AMI
data "aws_ssm_parameter" "ubuntu_ami" {
  name = "/aws/service/canonical/ubuntu/server/bionic/stable/current/amd64/hvm/ebs-gp2/ami-id"
}

# Backup bucket
resource "aws_s3_bucket" "mongo_backups" {
  bucket = "${var.name_prefix}-mongo-backups"
}

# Prevent public ACLs on the bucket
resource "aws_s3_bucket_public_access_block" "mongo_backups" {
  bucket = aws_s3_bucket.mongo_backups.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Encrypt all objects in the bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "mongo_backups" {
  bucket = aws_s3_bucket.mongo_backups.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# MongoDB VM instance
resource "aws_instance" "mongo_vm" {
  ami                         = data.aws_ssm_parameter.ubuntu_ami.value
  instance_type               = var.mongo_instance_type
  subnet_id                   = values(aws_subnet.public)[0].id # pick the first public subnet
  associate_public_ip_address = true
  key_name                    = var.ssh_key_name

  tags = {
    Name = "${var.name_prefix}-mongo-vm"
  }
}

# Expose the VM’s public IP for other modules
output "mongo_vm_public_ip" {
  description = "Public IP address of the MongoDB EC2 instance"
  value       = aws_instance.mongo_vm.public_ip
}