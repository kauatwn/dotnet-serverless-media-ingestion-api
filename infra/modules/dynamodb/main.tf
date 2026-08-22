# Amazon DynamoDB - Metadata Storage
resource "aws_dynamodb_table" "this" {
  name                        = var.dynamodb_table_name
  billing_mode                = "PAY_PER_REQUEST"
  hash_key                    = "imageId"
  deletion_protection_enabled = var.environment == "prod" ? true : false

  attribute {
    name = "imageId"
    type = "S"
  }

  point_in_time_recovery {
    enabled = var.enable_point_in_time_recovery
  }

  server_side_encryption {
    enabled = true
  }

  tags = merge(
    {
      Component   = "DynamoDB"
      Environment = var.environment
      Name        = var.dynamodb_table_name
    },
    var.tags
  )
}
