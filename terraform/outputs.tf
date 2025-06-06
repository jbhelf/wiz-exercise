output "mongo_vm_public_ip" {
  description = "The public IP address of the MongoDB EC2 instance"
  value       = aws_instance.mongo_vm.public_ip
}