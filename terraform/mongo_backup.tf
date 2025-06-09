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

  block_public_acls = true
  block_public_policy = true
  ignore_public_acls = true
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
  ami = data.aws_ssm_parameter.ubuntu_ami.value
  instance_type = var.mongo_instance_type
  subnet_id = values(aws_subnet.public)[0].id # pick the first public subnet
  associate_public_ip_address = true
  key_name = var.ssh_key_name
  iam_instance_profile = aws_iam_instance_profile.mongo_vm_profile.name
  vpc_security_group_ids = [aws_security_group.mongo_sg.id]

  #Outdated MongoDB with authentication enabled
  user_data = <<-EOF
    #!/bin/bash
    set -e
    apt-get update -y
    apt-get install -y gnupg wget
    # Install MongoDB 4.0 (outdated)
    wget -qO - https://www.mongodb.org/static/pgp/server-4.0.asc | apt-key add -
    echo "deb [arch=amd64] http://repo.mongodb.org/apt/ubuntu bionic/mongodb-org/4.0 multiverse" \
      | tee /etc/apt/sources.list.d/mongodb-org-4.0.list
    apt-get update -y
    apt-get install -y mongodb-org=4.0.28
    # Enable auth
    sed -i 's/#security:/security:\\n  authorization: "enabled"/' /etc/mongod.conf
    systemctl enable mongod
    systemctl start mongod
    # Create admin user
    mongo admin --eval 'db.createUser({user:"admin",pwd:"YourStrongP@ssw0rd",roles:["root"]})'
  EOF

  # Copy and schedule backup script
  provisioner "file" {
    source      = "${path.module}/../backup-mongo.sh"
    destination = "/tmp/backup-mongo.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/backup-mongo.sh",
      "(crontab -l 2>/dev/null; echo '0 2 * * * /tmp/backup-mongo.sh') | crontab -"
    ]
  }

  connection {
    type        = "ssh"
    host        = self.public_ip
    user        = "ubuntu"
    private_key = file(var.ssh_private_key_path)
  }

  tags = {
    Name = "${var.name_prefix}-mongo-vm"
  }
}

# Expose the VM’s public IP for other modules
output "mongo_vm_public_ip" {
  description = "Public IP address of the MongoDB EC2 instance"
  value = aws_instance.mongo_vm.public_ip
}