provider "aws" {
  access_key                  = "test"
  secret_key                  = "test"
  region                      = "us-east-1"
  
  # LocalStack configuration
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  skip_region_validation      = true
  
  # S3 path-style addressing (required for LocalStack to avoid DNS lookups)
  s3_use_path_style = true
  
  endpoints {
    lambda          = "http://localhost:4566"
    apigateway      = "http://localhost:4566"
    iam             = "http://localhost:4566"
    sts             = "http://localhost:4566"
    dynamodb        = "http://localhost:4566"
    s3              = "http://localhost:4566"
    ssm             = "http://localhost:4566"
    secretsmanager  = "http://localhost:4566"
  }
}
