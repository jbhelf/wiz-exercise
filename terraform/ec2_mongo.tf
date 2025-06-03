########################################
# ec2_mongo.tf
#
# Provision an Ubuntu 18.04 EC2 instance (t2.micro),
# install MongoDB 4.0, create an admin user, bind to 0.0.0.0,
# and schedule a daily backup script to push .tar.gz to S3.
########################################

# 1) Lookup Ubuntu 18.04 LTS AMI via SSM Parameter Store
data "aws_ssm_parameter" "ubuntu_bionic_ami" {
  name = "/aws/service/canonical/ubuntu/server/bionic/stable/current/amd64/hvm/ebs-gp2/ami-id"
}

# 2) EC2 instance for Mongo VM
resource "aws_instance" "mongo_vm" {
  ami           = data.aws_ssm_parameter.ubuntu_bionic_ami.value
  instance_type = var.mongo_instance_type
  key_name      = var.ssh_key_name
  subnet_id     = aws_subnet.public.id
  vpc_security_group_ids = [
    aws_security_group.sg_mongo_ssh.id,
    aws_security_group.sg_mongo_db.id
  ]
  iam_instance_profile        = aws_iam_instance_profile.mongo_instance_profile.name
  associate_public_ip_address = true

  tags = {
    Name = "${var.name_prefix}-mongo-vm"
  }

  # User data: install MongoDB 4.0, create admin, bind all, schedule backup
  user_data = <<-EOF
              #!/bin/bash
              apt-get update -y

              # Add MongoDB 4.0 repo
              wget -qO - https://www.mongodb.org/static/pgp/server-4.0.asc | apt-key add -
              echo "deb [ arch=amd64 ] https://repo.mongodb.org/apt/ubuntu bionic/mongodb-org/4.0 multiverse" \
                | tee /etc/apt/sources.list.d/mongodb-org-4.0.list

              apt-get update -y
              apt-get install -y mongodb-org=4.0.28 mongodb-org-server=4.0.28 mongodb-org-shell=4.0.28 mongodb-org-tools=4.0.28

              systemctl start mongod
              systemctl enable mongod

              # Wait until MongoDB is listening
              until nc -z localhost 27017; do sleep 1; done

              # Create MongoDB admin user
              mongo <<MONGO_INIT
              use admin;
              db.createUser({
                user: "admin",
                pwd: "P@ssw0rd123",
                roles: [{ role: "root", db: "admin" }]
              });
              MONGO_INIT

              # Enable auth and bind to all interfaces
              sed -i 's/^  bindIp:.*/  bindIp: 0.0.0.0/' /etc/mongod.conf
              sed -i 's/^#security:/security:\\n  authorization: "enabled"/' /etc/mongod.conf
              systemctl restart mongod

              # Create backup script
              cat <<'BACKUP_SH' > /usr/local/bin/mongo_backup.sh
              #!/bin/bash
              TIMESTAMP=$(date +%F)
              BACKUP_DIR="/tmp/mongo-backup-$TIMESTAMP"
              mkdir -p "$BACKUP_DIR"
              mongodump --authenticationDatabase admin -u admin -p 'P@ssw0rd123' --out "$BACKUP_DIR"
              tar czf /tmp/mongo-dump-$TIMESTAMP.tar.gz -C /tmp mongo-backup-$TIMESTAMP
              aws s3 cp /tmp/mongo-dump-$TIMESTAMP.tar.gz s3://${aws_s3_bucket.mongo_backups.id}/mongo-dump-$TIMESTAMP.tar.gz --acl public-read
              rm -rf "$BACKUP_DIR" /tmp/mongo-dump-$TIMESTAMP.tar.gz
              BACKUP_SH

              chmod +x /usr/local/bin/mongo_backup.sh

              # Schedule daily backup at 02:00 UTC
              (crontab -l 2>/dev/null; echo "0 2 * * * /usr/local/bin/mongo_backup.sh") | crontab -
              EOF
}