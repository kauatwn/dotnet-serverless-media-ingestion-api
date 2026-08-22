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
  bucket_arn          = "arn:aws:s3:::${local.bucket_name}"
}

# 1. Pure Module: Amazon S3 Bucket
module "s3" {
  source = "../../modules/s3"

  bucket_name = local.bucket_name
  environment = var.environment
  tags        = local.common_tags
}

# 2. Pure Module: Amazon DynamoDB Metadata Table
module "dynamodb" {
  source = "../../modules/dynamodb"

  dynamodb_table_name           = local.dynamodb_table_name
  environment                   = var.environment
  enable_point_in_time_recovery = false
  tags                          = local.common_tags
}

# 3. Pure Module: Amazon ECR Repository
module "ecr" {
  source = "../../modules/ecr"

  ecr_repository_name  = local.ecr_repo_name
  image_tag_mutability = "IMMUTABLE"
  scan_on_push         = true
  environment          = var.environment
  tags                 = local.common_tags
}

# 4. Pure Module: AWS Lambda Function (Glue Code dynamically receiving outputs from ECR, S3, and DynamoDB)
module "lambda" {
  source = "../../modules/lambda"

  ecr_repository_url  = module.ecr.ecr_repository_url
  function_name       = local.function_name
  image_tag           = var.image_tag
  lambda_architecture = var.lambda_architecture
  memory_size         = var.lambda_config.memory_size
  timeout             = var.lambda_config.timeout
  bucket_name         = module.s3.bucket_id
  bucket_arn          = local.bucket_arn
  dynamodb_table_name = module.dynamodb.dynamodb_table_name
  dynamodb_table_arn  = module.dynamodb.dynamodb_table_arn
  tracing_mode        = "PassThrough"
  environment         = var.environment
  tags                = local.common_tags
}

# 5. Pure Module: Amazon API Gateway REST API (Glue Code dynamically receiving outputs from Lambda)
module "apigateway" {
  source = "../../modules/apigateway"

  api_name             = local.api_name
  stage_name           = var.stage_name
  lambda_invoke_arn    = module.lambda.lambda_invoke_arn
  lambda_function_name = module.lambda.lambda_function_name
  binary_media_types   = []
  environment          = var.environment
  tags                 = local.common_tags
}
