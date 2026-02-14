# SSM Parameter: LLM mode for document summarization ("local" or "remote")
resource "aws_ssm_parameter" "summarize_llm_mode" {
  name        = "/poc-doc-process/summarize-document/llm-mode"
  description = "LLM mode for summarize_document Lambda: local or remote"
  type        = "String"
  value       = "local"

  tags = {
    Purpose = "summarize_document"
  }
}
