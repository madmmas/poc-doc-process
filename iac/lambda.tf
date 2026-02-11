# Lambda function for hello endpoint
resource "aws_lambda_function" "hello_lambda" {
  filename         = "../lambdas/hello_lambda.zip"
  function_name    = "hello-lambda"
  role            = aws_iam_role.lambda_role.arn
  handler         = "lambda_function.lambda_handler"
  runtime         = "python3.11"
  source_code_hash = filebase64sha256("../lambdas/hello_lambda.zip")

  depends_on = [aws_iam_role_policy_attachment.lambda_policy]
}

# Lambda function for health check endpoint
resource "aws_lambda_function" "health_lambda" {
  filename         = "../lambdas/health_lambda.zip"
  function_name    = "health-lambda"
  role            = aws_iam_role.lambda_role.arn
  handler         = "health_lambda.lambda_handler"
  runtime         = "python3.11"
  timeout         = 10
  source_code_hash = filebase64sha256("../lambdas/health_lambda.zip")

  environment {
    variables = {
      # Must match compose service name so Lambda container can resolve hostname
      DYNAMODB_ENDPOINT   = "http://localstack-us-east-1:4566"
      LOCALSTACK_HOSTNAME = "localstack-us-east-1"
      HEALTH_TABLE_NAME   = aws_dynamodb_table.health_table.name
      AWS_DEFAULT_REGION  = "us-east-1"
      AWS_ACCESS_KEY_ID   = "test"
      AWS_SECRET_ACCESS_KEY = "test"
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_policy,
    aws_iam_role_policy.dynamodb_policy,
    aws_dynamodb_table.health_table
  ]
}

# Lambda permission for API Gateway (hello)
resource "aws_lambda_permission" "api_gateway_hello" {
  statement_id  = "AllowExecutionFromAPIGatewayHello"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.hello_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.hello_api.execution_arn}/*/*"
}

# Lambda permission for API Gateway (health)
resource "aws_lambda_permission" "api_gateway_health" {
  statement_id  = "AllowExecutionFromAPIGatewayHealth"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.health_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.hello_api.execution_arn}/*/*"
}
