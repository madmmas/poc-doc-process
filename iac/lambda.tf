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

# Lambda function for document summarization (triggered by S3)
resource "aws_lambda_function" "summarize_document" {
  filename         = "../lambdas/summarize_document.zip"
  function_name    = "summarize_document"
  role            = aws_iam_role.lambda_role.arn
  handler         = "summarize_document.lambda_handler"
  runtime         = "python3.11"
  timeout         = 300  # 5 minutes for document processing
  source_code_hash = filebase64sha256("../lambdas/summarize_document.zip")

  environment {
    variables = {
      S3_BUCKET_NAME       = aws_s3_bucket.scrap_document_poc.bucket
      S3_ENDPOINT_URL      = "http://localstack-us-east-1:4566"  # LocalStack S3 endpoint
      LOCALSTACK_HOSTNAME   = "localstack-us-east-1"
      AWS_DEFAULT_REGION   = "us-east-1"
      AWS_ACCESS_KEY_ID    = "test"
      AWS_SECRET_ACCESS_KEY = "test"
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_policy,
    aws_iam_role_policy.s3_policy,
    aws_s3_bucket.scrap_document_poc
  ]
}

# Lambda permission for S3 to invoke summarize_document
resource "aws_lambda_permission" "s3_invoke_summarize_document" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.summarize_document.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.scrap_document_poc.arn
}
