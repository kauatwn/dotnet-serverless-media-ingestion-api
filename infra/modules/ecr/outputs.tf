output "ecr_repository_url" {
  type        = string
  description = "The repository URL of the ECR repository."
  value       = aws_ecr_repository.this.repository_url
}

output "ecr_repository_name" {
  type        = string
  description = "The name of the ECR repository."
  value       = aws_ecr_repository.this.name
}

output "ecr_repository_arn" {
  type        = string
  description = "The ARN of the ECR repository."
  value       = aws_ecr_repository.this.arn
}
