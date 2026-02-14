# Secrets Manager: OPENAI_API_KEY for document summarization (e.g. remote LLM)
variable "openai_api_key" {
  description = "OpenAI API key for summarization. Set via TF_VAR_openai_api_key or -var. Leave empty for LocalStack/dev placeholder."
  type        = string
  default     = ""
  sensitive   = true
}

resource "aws_secretsmanager_secret" "openai_api_key" {
  name                    = "poc-doc-process/openai-api-key"
  description             = "OPENAI_API_KEY for document summarization (OpenAI/remote LLM)"
  recovery_window_in_days = 0

  tags = {
    Purpose = "summarize_document"
  }
}

resource "aws_secretsmanager_secret_version" "openai_api_key" {
  secret_id     = aws_secretsmanager_secret.openai_api_key.id
  secret_string = coalesce(var.openai_api_key, "replace-me-localstack")
}
