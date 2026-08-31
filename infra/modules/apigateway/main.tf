# API Gateway (REST API)
resource "aws_api_gateway_rest_api" "this" {
  name               = var.api_name
  description        = "Serverless REST API for image processing (${var.environment})"
  binary_media_types = var.binary_media_types

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

  source_arn = "${aws_api_gateway_rest_api.this.execution_arn}/*/${aws_api_gateway_method.post_images.http_method}/${aws_api_gateway_resource.images.path_part}"
}

# HTTP Method (OPTIONS /images - CORS pre-flight)
resource "aws_api_gateway_method" "options_images" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.images.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

# Mock Integration for OPTIONS
resource "aws_api_gateway_integration" "options_images" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.images.id
  http_method = aws_api_gateway_method.options_images.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

# Method Response for OPTIONS (200 OK)
resource "aws_api_gateway_method_response" "options_images_200" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.images.id
  http_method = aws_api_gateway_method.options_images.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

# Integration Response for OPTIONS (200 OK)
resource "aws_api_gateway_integration_response" "options_images_200" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.images.id
  http_method = aws_api_gateway_method.options_images.http_method
  status_code = aws_api_gateway_method_response.options_images_200.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,Authorization,X-Amz-Date,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'POST,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }

  depends_on = [aws_api_gateway_integration.options_images]
}

# API Deployment
resource "aws_api_gateway_deployment" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.images.id,
      aws_api_gateway_method.post_images.id,
      aws_api_gateway_integration.this.id,
      aws_api_gateway_method.options_images.id,
      aws_api_gateway_integration.options_images.id,
      aws_api_gateway_integration_response.options_images_200.id
    ]))
  }

  depends_on = [
    aws_api_gateway_integration.this,
    aws_lambda_permission.this,
    aws_api_gateway_integration.options_images,
    aws_api_gateway_integration_response.options_images_200
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
