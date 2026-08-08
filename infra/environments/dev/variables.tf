variable "aws_region" {
  type        = string
  default     = "us-east-1"
  description = "AWS region for deployment."

  validation {
    condition     = can(regex("^[a-z]{2}-(?:gov-)?(?:east|west|north|south|central|northeast|southeast|southwest)-[1-4]$", var.aws_region))
    error_message = "The aws_region must be a valid AWS region identifier (e.g., us-east-1, us-west-2, eu-west-1)."
  }
}

variable "environment" {
  type        = string
  default     = "dev"
  description = "Target deployment environment identifier (e.g., dev, staging, prod)."

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "The environment variable must be one of: 'dev', 'staging', 'prod'."
  }
}

variable "project_name" {
  type        = string
  default     = "imageprocessor"
  description = "Short identifier for the project used in resource naming and tags."

  validation {
    condition     = can(regex("^[a-z0-9-]{3,30}$", var.project_name))
    error_message = "The project_name must be between 3 and 30 lowercase alphanumeric characters or hyphens."
  }
}

variable "localstack_endpoint" {
  type        = string
  default     = "http://127.0.0.1:4566"
  description = "LocalStack endpoint URL for local AWS emulation."

  validation {
    condition     = can(regex("^https?://", var.localstack_endpoint))
    error_message = "The localstack_endpoint must be a valid HTTP or HTTPS URL."
  }
}

variable "lambda_architecture" {
  type        = string
  default     = "x86_64"
  description = "Architecture for the Lambda function (x86_64 or arm64)."

  validation {
    condition     = contains(["x86_64", "arm64"], var.lambda_architecture)
    error_message = "The lambda_architecture must be either 'x86_64' or 'arm64'."
  }
}

variable "image_tag" {
  type        = string
  default     = "latest"
  description = "Docker image tag used by Lambda container function."

  validation {
    condition     = length(trimspace(var.image_tag)) > 0
    error_message = "The image_tag must not be empty."
  }
}

variable "lambda_config" {
  type = object({
    memory_size = number
    timeout     = number
  })
  default = {
    memory_size = 512
    timeout     = 15
  }
  description = "Lambda resource sizing and execution timeout configuration."

  validation {
    condition     = var.lambda_config.memory_size >= 128 && var.lambda_config.memory_size <= 10240 && var.lambda_config.timeout >= 1 && var.lambda_config.timeout <= 900
    error_message = "The lambda_config memory_size must be between 128 and 10240 MB, and timeout must be between 1 and 900 seconds."
  }
}