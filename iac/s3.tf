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

# S3 bucket for admin web app (static website hosting)
resource "aws_s3_bucket" "admin_web" {
  bucket        = "admin-web-poc"
  force_destroy = true

  tags = {
    Name        = "Admin Web App"
    Environment = "dev"
  }
}

# Enable static website hosting for admin web bucket
resource "aws_s3_bucket_website_configuration" "admin_web" {
  bucket = aws_s3_bucket.admin_web.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "404.html"
  }
}

# Public read access for admin web bucket (for static website)
resource "aws_s3_bucket_public_access_block" "admin_web" {
  bucket = aws_s3_bucket.admin_web.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# Bucket policy for public read access
resource "aws_s3_bucket_policy" "admin_web" {
  bucket = aws_s3_bucket.admin_web.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.admin_web.arn}/*"
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.admin_web]
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
