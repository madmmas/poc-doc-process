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

# API Gateway Deployment
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
  ]
}

# API Gateway Stage
resource "aws_api_gateway_stage" "hello_stage" {
  deployment_id = aws_api_gateway_deployment.hello_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.hello_api.id
  stage_name    = "dev"
}
