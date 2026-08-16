# API Gateway (REST API)
resource "aws_api_gateway_rest_api" "this" {
  name        = var.api_name
  description = "Serverless REST API for image processing (${var.environment})"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = merge(
    {
      Component   = "APIGateway"
      Environment = var.environment
      Name        = var.api_name
    },
    var.tags
  )
}

# API Resource / Route (/images)
resource "aws_api_gateway_resource" "images" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = "images"
}

# HTTP Method (POST /images)
resource "aws_api_gateway_method" "post_images" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.images.id
  http_method   = "POST"
  authorization = "NONE"
}

# API Gateway to Lambda Integration
resource "aws_api_gateway_integration" "this" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.images.id
  http_method             = aws_api_gateway_method.post_images.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.lambda_invoke_arn
}

# Invocation Permission for API Gateway
resource "aws_lambda_permission" "this" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.this.execution_arn}/${var.stage_name}/${aws_api_gateway_method.post_images.http_method}/${aws_api_gateway_resource.images.path_part}"
}

# API Deployment
resource "aws_api_gateway_deployment" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.images.id,
      aws_api_gateway_method.post_images.id,
      aws_api_gateway_integration.this.id,
    ]))
  }

  depends_on = [
    aws_api_gateway_integration.this,
    aws_lambda_permission.this
  ]

  lifecycle {
    create_before_destroy = true
  }
}

# API Gateway Stage
resource "aws_api_gateway_stage" "this" {
  deployment_id = aws_api_gateway_deployment.this.id
  rest_api_id   = aws_api_gateway_rest_api.this.id
  stage_name    = var.stage_name

  tags = merge(
    {
      Component   = "APIGateway"
      Environment = var.environment
      Name        = "${var.api_name}-${var.stage_name}"
    },
    var.tags
  )
}
