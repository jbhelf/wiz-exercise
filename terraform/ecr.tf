#######################################
# ecr.tf
#
# 1) Create an AWS ECR repository for Tasky
#######################################

resource "aws_ecr_repository" "tasky" {
  name                 = "${var.name_prefix}-tasky-repo"
  image_tag_mutability = "MUTABLE"

  tags = {
    Name = "${var.name_prefix}-tasky-repo"
  }
}

output "tasky_ecr_url" {
  description = "The URI of the Tasky ECR repository"
  value       = aws_ecr_repository.tasky.repository_url
}