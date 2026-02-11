# DynamoDB table for health checks
resource "aws_dynamodb_table" "health_table" {
  name           = "health-check-table"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "id"

  attribute {
    name = "id"
    type = "S"
  }

  tags = {
    Name        = "Health Check Table"
    Environment = "dev"
  }
}
