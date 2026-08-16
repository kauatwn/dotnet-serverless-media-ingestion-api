output "lambda_function_name" {
  type        = string
  description = "The function name of the Lambda function."
  value       = aws_lambda_function.this.function_name
}

output "lambda_invoke_arn" {
  type        = string
  description = "The invocation ARN of the Lambda function."
  value       = aws_lambda_function.this.invoke_arn
}

output "lambda_arn" {
  type        = string
  description = "The full ARN of the Lambda function."
  value       = aws_lambda_function.this.arn
}

output "lambda_role_arn" {
  type        = string
  description = "The ARN of the IAM role attached to the Lambda function."
  value       = aws_iam_role.this.arn
}
