output "api_url" {
  type        = string
  description = "The invocation URL of the API endpoint."
  value       = module.apigateway.api_url
}

output "api_id" {
  type        = string
  description = "The ID of the REST API Gateway."
  value       = module.apigateway.api_id
}

output "s3_bucket_name" {
  type        = string
  description = "The unique name of the S3 bucket created for image storage."
  value       = module.s3.bucket_id
}

output "s3_bucket_arn" {
  type        = string
  description = "The ARN of the S3 bucket."
  value       = module.s3.bucket_arn
}

output "dynamodb_table_name" {
  type        = string
  description = "The name of the DynamoDB metadata table."
  value       = module.dynamodb.dynamodb_table_name
}

output "dynamodb_table_arn" {
  type        = string
  description = "The ARN of the DynamoDB metadata table."
  value       = module.dynamodb.dynamodb_table_arn
}

output "ecr_repository_url" {
  type        = string
  description = "The registry URL of the Lambda ECR repository."
  value       = module.ecr.ecr_repository_url
}

output "lambda_function_name" {
  type        = string
  description = "Name of the provisioned Lambda function."
  value       = module.lambda.lambda_function_name
}
