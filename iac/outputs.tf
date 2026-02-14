# Output the API Gateway URLs
output "api_gateway_hello_url" {
  value = "http://localhost:4566/restapis/${aws_api_gateway_rest_api.hello_api.id}/${aws_api_gateway_stage.hello_stage.stage_name}/_user_request_/hello"
  description = "API Gateway hello endpoint URL"
}

output "api_gateway_health_url" {
  value = "http://localhost:4566/restapis/${aws_api_gateway_rest_api.hello_api.id}/${aws_api_gateway_stage.hello_stage.stage_name}/_user_request_/health"
  description = "API Gateway health endpoint URL"
}

output "lambda_function_names" {
  value = {
    hello = aws_lambda_function.hello_lambda.function_name
    health = aws_lambda_function.health_lambda.function_name
  }
  description = "Names of the Lambda functions"
}

output "dynamodb_table_name" {
  value = aws_dynamodb_table.health_table.name
  description = "Name of the DynamoDB table"
}

output "api_gateway_id" {
  value = aws_api_gateway_rest_api.hello_api.id
  description = "ID of the API Gateway"
}

# output "api_gateway_fastapi_url" {
#   value = "http://localhost:4566/restapis/${aws_api_gateway_rest_api.hello_api.id}/${aws_api_gateway_stage.hello_stage.stage_name}/_user_request_/api"
#   description = "API Gateway FastAPI base URL (use /api/upload, /api/upload/json, /api/health endpoints)"
# }

# output "fastapi_lambda_function_name" {
#   value = aws_lambda_function.fastapi_s3_upload.function_name
#   description = "Name of the FastAPI Lambda function"
# }

# output "admin_web_bucket_name" {
#   value = aws_s3_bucket.admin_web.bucket
#   description = "Name of the S3 bucket for admin web app"
# }

# output "admin_web_website_url" {
#   value = "http://${aws_s3_bucket.admin_web.bucket}.s3-website-us-east-1.amazonaws.com"
#   description = "Website URL for admin web app. For LocalStack, use: http://localhost:4566/admin-web-poc"
# }

# output "summarize_llm_mode_parameter" {
#   value       = aws_ssm_parameter.summarize_llm_mode.name
#   description = "SSM parameter name for summarize_document LLM mode (local or remote)"
# }
