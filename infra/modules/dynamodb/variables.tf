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
