########################################
# ecr.tf
# ECR repository for Tasky Docker images
########################################

resource "aws_ecr_repository" "tasky" {
  name                 = "${var.name_prefix}-tasky-repo"
  image_tag_mutability = "MUTABLE"

  tags = {
    Name = "${var.name_prefix}-tasky-repo"
  }
}

output "tasky_ecr_url" {
  description = "URI for Tasky Docker images"
  value       = aws_ecr_repository.tasky.repository_url
}