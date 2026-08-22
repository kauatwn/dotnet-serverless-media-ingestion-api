output "dynamodb_table_name" {
  type        = string
  description = "The name of the DynamoDB metadata table."
  value       = aws_dynamodb_table.this.name
}

output "dynamodb_table_arn" {
  type        = string
  description = "The ARN of the DynamoDB metadata table."
  value       = aws_dynamodb_table.this.arn
}

output "dynamodb_table_id" {
  type        = string
  description = "The ID of the DynamoDB table."
  value       = aws_dynamodb_table.this.id
}
