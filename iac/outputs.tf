output "summarize_llm_mode_parameter" {
  value       = aws_ssm_parameter.summarize_llm_mode.name
  description = "SSM parameter name for summarize_document LLM mode (local or remote)"
}

output "openai_api_key_secret_name" {
  value       = aws_secretsmanager_secret.openai_api_key.name
  description = "Secrets Manager secret name for OPENAI_API_KEY"
}
