variable "ecr_repository_name" {
  type        = string
  description = "Name of the ECR repository for Lambda container image."

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9._/-]{1,254}$", var.ecr_repository_name))
    error_message = "The ecr_repository_name must be a valid ECR repository name (lowercase alphanumeric characters, hyphens, underscores, periods, and forward slashes)."
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
