# Amazon ECR Repository for Lambda container images
resource "aws_ecr_repository" "this" {
  name                 = var.ecr_repository_name
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = false
  }

  tags = merge(
    {
      Component   = "Compute"
      Environment = var.environment
      Name        = var.ecr_repository_name
    },
    var.tags
  )
}

# ECR Lifecycle Policy (Keep last 5 untagged images)
resource "aws_ecr_lifecycle_policy" "this" {
  repository = aws_ecr_repository.this.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Expire untagged images older than 5 counts"
      selection = {
        tagStatus   = "untagged"
        countType   = "imageCountMoreThan"
        countNumber = 5
      }
      action = {
        type = "expire"
      }
    }]
  })
}

# CloudWatch Log Group for Lambda
resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = 7

  tags = merge(
    {
      Component   = "Compute"
      Environment = var.environment
    },
    var.tags
  )
}

# IAM Execution Role for Lambda
resource "aws_iam_role" "this" {
  name = "${var.function_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    {
      Component   = "Compute"
      Environment = var.environment
    },
    var.tags
  )
}

# IAM Least Privilege Policy for Lambda
resource "aws_iam_role_policy" "this" {
  name = "${var.function_name}-permissions"
  role = aws_iam_role.this.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.this.arn}:*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject"
        ]
        Resource = "${var.bucket_arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem"
        ]
        Resource = [
          var.dynamodb_table_arn,
          "${var.dynamodb_table_arn}/index/*"
        ]
      }
    ]
  })
}

# AWS Lambda Function (Container Image)
resource "aws_lambda_function" "this" {
  function_name = var.function_name
  role          = aws_iam_role.this.arn
  architectures = [var.lambda_architecture]

  package_type = "Image"
  image_uri    = "${aws_ecr_repository.this.repository_url}:${var.image_tag}"

  memory_size = var.memory_size
  timeout     = var.timeout

  environment {
    variables = {
      BUCKET_NAME = var.bucket_name
      TABLE_NAME  = var.dynamodb_table_name
    }
  }

  tags = merge(
    {
      Component   = "Compute"
      Environment = var.environment
      Name        = var.function_name
    },
    var.tags
  )

  depends_on = [
    aws_cloudwatch_log_group.this
  ]
}