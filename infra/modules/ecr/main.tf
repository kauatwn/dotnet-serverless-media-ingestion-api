# Amazon ECR Repository for container images
resource "aws_ecr_repository" "this" {
  name                 = var.ecr_repository_name
  image_tag_mutability = var.image_tag_mutability
  force_delete         = var.environment == "dev" ? true : false

  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }

  tags = merge(
    {
      Component   = "ECR"
      Environment = var.environment
      Name        = var.ecr_repository_name
    },
    var.tags
  )
}

# ECR Lifecycle Policy (Keep last 10 untagged images)
resource "aws_ecr_lifecycle_policy" "this" {
  repository = aws_ecr_repository.this.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Expire untagged images older than 10 counts"
      selection = {
        tagStatus   = "untagged"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = {
        type = "expire"
      }
    }]
  })
}
