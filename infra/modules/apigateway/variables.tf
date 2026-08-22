variable "api_name" {
  type        = string
  description = "Name of the REST API Gateway."

  validation {
    condition     = can(regex("^[a-zA-Z0-9-_]{1,128}$", var.api_name))
    error_message = "The api_name must be between 1 and 128 characters long and contain letters, numbers, hyphens, or underscores."
  }
}

variable "stage_name" {
  type        = string
  default     = "local"
  description = "Deployment stage name for API Gateway."

  validation {
    condition     = can(regex("^[a-zA-Z0-9_]{1,128}$", var.stage_name))
    error_message = "The stage_name must be alphanumeric or underscores and 1 to 128 characters."
  }
}

variable "lambda_invoke_arn" {
  type        = string
  description = "The invocation ARN of the Lambda function to integrate with API Gateway."

  validation {
    condition     = length(trimspace(var.lambda_invoke_arn)) > 0
    error_message = "The lambda_invoke_arn must not be empty."
  }
}

variable "lambda_function_name" {
  type        = string
  description = "The name of the Lambda function for invocation permission."

  validation {
    condition     = length(trimspace(var.lambda_function_name)) > 0
    error_message = "The lambda_function_name must not be empty."
  }
}

variable "binary_media_types" {
  type        = list(string)
  default     = []
  description = "List of binary media types supported by the REST API."
}

variable "environment" {
  type        = string
  description = "Target deployment environment (e.g., dev, staging, prod)."

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "The environment variable must be one of: 'dev', 'staging', 'prod'."
  }
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Optional map of additional resource tags to be merged with component tags."
}
