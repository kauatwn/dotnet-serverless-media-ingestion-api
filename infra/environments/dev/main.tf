locals {
  common_tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = var.project_name
  }

  bucket_name         = "${var.project_name}-bucket-${var.environment}"
  dynamodb_table_name = "${var.project_name}-metadata-${var.environment}"
  ecr_repo_name       = "${var.project_name}-lambda-${var.environment}"
  function_name       = "${var.project_name}-upload-image-${var.environment}"
  api_name            = "${var.project_name}-api-${var.environment}"
}

# Dynamic Network Resolution (Default VPC & Subnets)
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# 1. Pure Module: S3 Storage & DynamoDB Metadata Table
module "storage" {
  source = "../../modules/storage"

  bucket_name         = local.bucket_name
  dynamodb_table_name = local.dynamodb_table_name
  environment         = var.environment
  tags                = local.common_tags
}

# 2. Pure Module: ECR Repository, IAM & Lambda Function (Glue Code dynamically receiving outputs from Storage)
module "compute" {
  source = "../../modules/compute"

  ecr_repository_name = local.ecr_repo_name
  function_name       = local.function_name
  image_tag           = var.image_tag
  lambda_architecture = var.lambda_architecture
  memory_size         = var.lambda_config.memory_size
  timeout             = var.lambda_config.timeout
  bucket_name         = module.storage.bucket_id
  bucket_arn          = module.storage.bucket_arn
  dynamodb_table_name = module.storage.dynamodb_table_name
  dynamodb_table_arn  = module.storage.dynamodb_table_arn
  environment         = var.environment
  tags                = local.common_tags
}

# 3. Pure Module: API Gateway REST API (Glue Code dynamically receiving outputs from Compute)
module "api" {
  source = "../../modules/api"

  api_name             = local.api_name
  stage_name           = "local"
  lambda_invoke_arn    = module.compute.lambda_invoke_arn
  lambda_function_name = module.compute.lambda_function_name
  environment          = var.environment
  tags                 = local.common_tags
}