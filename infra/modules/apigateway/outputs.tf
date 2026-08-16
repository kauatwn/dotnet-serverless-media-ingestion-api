output "api_id" {
  type        = string
  description = "The ID of the REST API Gateway."
  value       = aws_api_gateway_rest_api.this.id
}

output "api_url" {
  type        = string
  description = "The invocation URL of the API endpoint."
  value       = "${aws_api_gateway_stage.this.invoke_url}/${aws_api_gateway_resource.images.path_part}"
}

output "execution_arn" {
  type        = string
  description = "The execution ARN of the REST API Gateway."
  value       = aws_api_gateway_rest_api.this.execution_arn
}

output "stage_name" {
  type        = string
  description = "The stage name of the deployed REST API."
  value       = aws_api_gateway_stage.this.stage_name
}
