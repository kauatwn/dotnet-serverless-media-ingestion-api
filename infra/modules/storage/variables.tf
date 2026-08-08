variable "bucket_name" {
  type        = string
  description = "The unique name of the S3 bucket."

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.bucket_name))
    error_message = "The bucket_name must be between 3 and 63 characters long, contain only lowercase letters, numbers, hyphens, and dots, and start/end with an alphanumeric character."
  }
}

variable "dynamodb_table_name" {
  type        = string
  description = "The name of the DynamoDB metadata table."

  validation {
    condition     = can(regex("^[a-zA-Z0-9_.-]{3,255}$", var.dynamodb_table_name))
    error_message = "The dynamodb_table_name must be between 3 and 255 characters and contain only letters, numbers, hyphens, underscores, or dots."
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
