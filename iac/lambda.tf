# Lambda function for document summarization (triggered by S3)
resource "aws_lambda_function" "summarize_document" {
  filename         = "../lambdas/dist/summarize_document.zip"
  function_name    = "summarize_document"
  role            = aws_iam_role.lambda_role.arn
  handler         = "summarize_document.lambda_handler"
  runtime         = "python3.11"
  timeout         = 300  # 5 minutes for document processing
  source_code_hash = filebase64sha256("../lambdas/dist/summarize_document.zip")
  layers          = [aws_lambda_layer_version.python_common.arn]

  environment {
    variables = {
      S3_BUCKET_NAME             = aws_s3_bucket.scrap_document_poc.bucket
      S3_ENDPOINT_URL            = "http://localstack-us-east-1:4566"  # LocalStack S3 endpoint
      LOCALSTACK_HOSTNAME        = "localstack-us-east-1"
      AWS_DEFAULT_REGION         = "us-east-1"
      AWS_ACCESS_KEY_ID          = "test"
      AWS_SECRET_ACCESS_KEY      = "test"
      LLM_MODE                   = aws_ssm_parameter.summarize_llm_mode.value
      # Powertools
      POWERTOOLS_SERVICE_NAME    = "summarize_document"
      POWERTOOLS_METRICS_NAMESPACE = "PocDocProcess"
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_policy,
    aws_iam_role_policy.s3_policy,
    aws_s3_bucket.scrap_document_poc,
    aws_ssm_parameter.summarize_llm_mode,
    aws_lambda_layer_version.python_common
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
