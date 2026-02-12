# S3 bucket for document storage
# Folder structure:
#   - new/      : Upload documents here to trigger processing
#   - processed/: Successfully processed documents are moved here
#   - failed/   : Failed processing attempts are moved here
resource "aws_s3_bucket" "scrap_document_poc" {
  bucket        = "scrap-document-poc"
  force_destroy = true  # Allow bucket deletion even if not empty (useful for LocalStack)

  tags = {
    Name        = "Scrap Document POC"
    Environment = "dev"
  }
}

# S3 bucket versioning (optional - enable if needed)
resource "aws_s3_bucket_versioning" "scrap_document_poc_versioning" {
  bucket = aws_s3_bucket.scrap_document_poc.id

  versioning_configuration {
    status = "Disabled"
  }
}

# S3 bucket notification configuration - triggers Lambda on object creation in "new/" folder
# Note: LocalStack may have limitations with S3 bucket notifications. If you encounter 404 errors,
# try applying resources in stages: 1) bucket, 2) lambda + permission, 3) notification
resource "aws_s3_bucket_notification" "scrap_document_poc_notification" {
  bucket = aws_s3_bucket.scrap_document_poc.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.summarize_document.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "new/"  # Only trigger on objects uploaded to "new/" folder
    filter_suffix       = ".json" # Only trigger on JSON files
  }

  depends_on = [
    aws_lambda_function.summarize_document,
    aws_lambda_permission.s3_invoke_summarize_document,
    aws_s3_bucket.scrap_document_poc
  ]
}
