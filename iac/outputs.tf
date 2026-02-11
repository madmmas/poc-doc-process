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
