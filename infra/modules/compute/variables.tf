variable "function_name" {
  type        = string
  description = "Name of the AWS Lambda function."

  validation {
    condition     = can(regex("^[a-zA-Z0-9-_]{1,64}$", var.function_name))
    error_message = "The function_name must be between 1 and 64 characters long and contain letters, numbers, hyphens, or underscores."
  }
}

variable "ecr_repository_name" {
  type        = string
  description = "Name of the ECR repository for Lambda container image."

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9._/-]{1,254}$", var.ecr_repository_name))
    error_message = "The ecr_repository_name must be a valid ECR repository name (lowercase alphanumeric characters, hyphens, underscores, periods, and forward slashes)."
  }
}

variable "image_tag" {
  type        = string
  description = "Docker image tag to deploy."

  validation {
    condition     = length(trimspace(var.image_tag)) > 0
    error_message = "The image_tag must not be empty."
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

variable "memory_size" {
  type        = number
  default     = 512
  description = "Amount of memory in MB allocated to the Lambda function (128 to 10240)."

  validation {
    condition     = var.memory_size >= 128 && var.memory_size <= 10240
    error_message = "The memory_size must be between 128 MB and 10240 MB."
  }
}

variable "timeout" {
  type        = number
  default     = 15
  description = "Execution timeout in seconds for the Lambda function (1 to 900)."

  validation {
    condition     = var.timeout >= 1 && var.timeout <= 900
    error_message = "The timeout must be between 1 and 900 seconds."
  }
}

variable "bucket_name" {
  type        = string
  description = "The name of the S3 bucket for image processing."

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.bucket_name))
    error_message = "The bucket_name must be a valid S3 bucket name."
  }
}

variable "bucket_arn" {
  type        = string
  description = "The ARN of the S3 bucket for IAM permission scope."

  validation {
    condition     = can(regex("^arn:aws[a-zA-Z-]*:s3:::", var.bucket_arn))
    error_message = "The bucket_arn must be a valid S3 bucket ARN."
  }
}

variable "dynamodb_table_name" {
  type        = string
  description = "The name of the DynamoDB table for image metadata."

  validation {
    condition     = can(regex("^[a-zA-Z0-9_.-]{3,255}$", var.dynamodb_table_name))
    error_message = "The dynamodb_table_name must be a valid DynamoDB table name."
  }
}

variable "dynamodb_table_arn" {
  type        = string
  description = "The ARN of the DynamoDB table for IAM permission scope."

  validation {
    condition     = can(regex("^arn:aws[a-zA-Z-]*:dynamodb:", var.dynamodb_table_arn))
    error_message = "The dynamodb_table_arn must be a valid DynamoDB table ARN."
  }
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