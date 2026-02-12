# API Gateway REST API
resource "aws_api_gateway_rest_api" "hello_api" {
  name        = "hello-api"
  description = "API Gateway for Hello Lambda function"
}

# API Gateway Resource for hello endpoint
resource "aws_api_gateway_resource" "hello_resource" {
  rest_api_id = aws_api_gateway_rest_api.hello_api.id
  parent_id   = aws_api_gateway_rest_api.hello_api.root_resource_id
  path_part   = "hello"
}

# API Gateway Resource for health endpoint
resource "aws_api_gateway_resource" "health_resource" {
  rest_api_id = aws_api_gateway_rest_api.hello_api.id
  parent_id   = aws_api_gateway_rest_api.hello_api.root_resource_id
  path_part   = "health"
}

# API Gateway Method for hello (GET)
resource "aws_api_gateway_method" "hello_method" {
  rest_api_id   = aws_api_gateway_rest_api.hello_api.id
  resource_id   = aws_api_gateway_resource.hello_resource.id
  http_method   = "GET"
  authorization = "NONE"
}

# API Gateway Method for health (GET)
resource "aws_api_gateway_method" "health_method" {
  rest_api_id   = aws_api_gateway_rest_api.hello_api.id
  resource_id   = aws_api_gateway_resource.health_resource.id
  http_method   = "GET"
  authorization = "NONE"
}

# API Gateway Integration for hello
resource "aws_api_gateway_integration" "hello_integration" {
  rest_api_id = aws_api_gateway_rest_api.hello_api.id
  resource_id = aws_api_gateway_resource.hello_resource.id
  http_method = aws_api_gateway_method.hello_method.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.hello_lambda.invoke_arn
}

# API Gateway Integration for health
resource "aws_api_gateway_integration" "health_integration" {
  rest_api_id = aws_api_gateway_rest_api.hello_api.id
  resource_id = aws_api_gateway_resource.health_resource.id
  http_method = aws_api_gateway_method.health_method.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.health_lambda.invoke_arn
}

# API Gateway Resource for /api prefix (for FastAPI routes)
resource "aws_api_gateway_resource" "api_resource" {
  rest_api_id = aws_api_gateway_rest_api.hello_api.id
  parent_id   = aws_api_gateway_rest_api.hello_api.root_resource_id
  path_part   = "api"
}

# API Gateway Resource for FastAPI (catch-all proxy under /api)
resource "aws_api_gateway_resource" "fastapi_proxy" {
  rest_api_id = aws_api_gateway_rest_api.hello_api.id
  parent_id   = aws_api_gateway_resource.api_resource.id
  path_part   = "{proxy+}"
}

# API Gateway Method for FastAPI (ANY - catches all HTTP methods including OPTIONS)
resource "aws_api_gateway_method" "fastapi_proxy_method" {
  rest_api_id   = aws_api_gateway_rest_api.hello_api.id
  resource_id   = aws_api_gateway_resource.fastapi_proxy.id
  http_method   = "ANY"
  authorization = "NONE"
}

# Explicit OPTIONS method for CORS preflight (some clients need this)
resource "aws_api_gateway_method" "fastapi_options_method" {
  rest_api_id   = aws_api_gateway_rest_api.hello_api.id
  resource_id   = aws_api_gateway_resource.fastapi_proxy.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

# Mock integration for OPTIONS to return CORS headers immediately
resource "aws_api_gateway_integration" "fastapi_options_integration" {
  rest_api_id = aws_api_gateway_rest_api.hello_api.id
  resource_id = aws_api_gateway_resource.fastapi_proxy.id
  http_method = aws_api_gateway_method.fastapi_options_method.http_method

  type = "MOCK"
  
  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

# Method response for OPTIONS
resource "aws_api_gateway_method_response" "fastapi_options_response" {
  rest_api_id = aws_api_gateway_rest_api.hello_api.id
  resource_id = aws_api_gateway_resource.fastapi_proxy.id
  http_method = aws_api_gateway_method.fastapi_options_method.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin" = true
  }
}

# Integration response for OPTIONS
resource "aws_api_gateway_integration_response" "fastapi_options_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.hello_api.id
  resource_id = aws_api_gateway_resource.fastapi_proxy.id
  http_method = aws_api_gateway_method.fastapi_options_method.http_method
  status_code = aws_api_gateway_method_response.fastapi_options_response.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,POST,PUT,DELETE,OPTIONS,HEAD,PATCH'"
    "method.response.header.Access-Control-Allow-Origin" = "'*'"
  }

  depends_on = [aws_api_gateway_integration.fastapi_options_integration]
}

# API Gateway Integration for FastAPI
resource "aws_api_gateway_integration" "fastapi_proxy_integration" {
  rest_api_id = aws_api_gateway_rest_api.hello_api.id
  resource_id = aws_api_gateway_resource.fastapi_proxy.id
  http_method = aws_api_gateway_method.fastapi_proxy_method.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.fastapi_s3_upload.invoke_arn
}

# API Gateway Deployment (includes all routes: hello, health, and FastAPI)
resource "aws_api_gateway_deployment" "hello_deployment" {
  rest_api_id = aws_api_gateway_rest_api.hello_api.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.hello_resource.id,
      aws_api_gateway_method.hello_method.id,
      aws_api_gateway_integration.hello_integration.id,
      aws_api_gateway_resource.health_resource.id,
      aws_api_gateway_method.health_method.id,
      aws_api_gateway_integration.health_integration.id,
      aws_api_gateway_resource.api_resource.id,
      aws_api_gateway_resource.fastapi_proxy.id,
      aws_api_gateway_method.fastapi_proxy_method.id,
      aws_api_gateway_integration.fastapi_proxy_integration.id,
      aws_api_gateway_method.fastapi_options_method.id,
      aws_api_gateway_integration.fastapi_options_integration.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_method.hello_method,
    aws_api_gateway_integration.hello_integration,
    aws_api_gateway_method.health_method,
    aws_api_gateway_integration.health_integration,
    aws_api_gateway_method.fastapi_proxy_method,
    aws_api_gateway_integration.fastapi_proxy_integration,
    aws_api_gateway_method.fastapi_options_method,
    aws_api_gateway_integration.fastapi_options_integration,
    aws_api_gateway_integration_response.fastapi_options_integration_response,
  ]
}

# API Gateway Stage
resource "aws_api_gateway_stage" "hello_stage" {
  deployment_id = aws_api_gateway_deployment.hello_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.hello_api.id
  stage_name    = "dev"
}
