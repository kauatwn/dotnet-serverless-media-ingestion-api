# CloudWatch Log Group for Lambda
resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = var.log_retention_in_days

  tags = merge(
    {
      Component   = "Lambda"
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
      Component   = "Lambda"
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
  image_uri    = "${var.ecr_repository_url}:${var.image_tag}"

  memory_size = var.memory_size
  timeout     = var.timeout

  tracing_config {
    mode = var.tracing_mode
  }

  environment {
    variables = {
      BUCKET_NAME = var.bucket_name
      TABLE_NAME  = var.dynamodb_table_name
    }
  }

  tags = merge(
    {
      Component   = "Lambda"
      Environment = var.environment
      Name        = var.function_name
    },
    var.tags
  )

  depends_on = [
    aws_cloudwatch_log_group.this
  ]
}
