# Lambda layer: common Python libraries (Powertools, etc.) - built with uv
resource "aws_lambda_layer_version" "python_common" {
  filename            = "../lambdas/dist/python-common-layer.zip"
  layer_name         = "python-common"
  description         = "Common Python libs: aws-lambda-powertools (logger, metrics)"
  compatible_runtimes = ["python3.11"]
  compatible_architectures = ["x86_64"]
}
