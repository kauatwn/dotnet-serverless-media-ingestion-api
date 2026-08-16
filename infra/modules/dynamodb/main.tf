# Amazon DynamoDB - Metadata Storage
resource "aws_dynamodb_table" "this" {
  name         = var.dynamodb_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "imageId"

  attribute {
    name = "imageId"
    type = "S"
  }

  point_in_time_recovery {
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
