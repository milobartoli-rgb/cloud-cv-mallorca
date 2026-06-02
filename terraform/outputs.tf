# =====================================================
# Cloud CV Mallorca - Outputs de Terraform
# =====================================================

output "api_gateway_url" {
  description = "URL base de l'API Gateway"
  value       = aws_api_gateway_stage.prod.invoke_url
}

output "api_endpoint_visites" {
  description = "URL completa de l'endpoint de visites"
  value       = "${aws_api_gateway_stage.prod.invoke_url}/visites"
}

output "api_gateway_id" {
  description = "ID de l'API Gateway"
  value       = aws_api_gateway_rest_api.cv_api.id
}

output "lambda_function_name" {
  description = "Nom de la funció Lambda"
  value       = aws_lambda_function.visitor_counter.function_name
}

output "lambda_function_arn" {
  description = "ARN de la funció Lambda"
  value       = aws_lambda_function.visitor_counter.arn
}

output "dynamodb_table_name" {
  description = "Nom de la taula DynamoDB"
  value       = aws_dynamodb_table.visitor_counter.name
}

output "cloudwatch_log_group" {
  description = "Nom del grup de logs de CloudWatch"
  value       = aws_cloudwatch_log_group.lambda_logs.name
}

output "lambda_role_arn" {
  description = "ARN del rol IAM de Lambda"
  value       = data.aws_iam_role.lambda_role.arn
}

# -----------------------------------------------------
# Outputs d'Amplify
# -----------------------------------------------------

output "amplify_app_id" {
  description = "ID de l'aplicacio Amplify"
  value       = var.github_token != "" ? aws_amplify_app.cv_app[0].id : "Amplify no configurat (falta github_token)"
  sensitive   = true
}

output "amplify_default_domain" {
  description = "Domini per defecte d'Amplify"
  value       = var.github_token != "" ? aws_amplify_app.cv_app[0].default_domain : "Amplify no configurat (falta github_token)"
  sensitive   = true
}

output "amplify_app_url" {
  description = "URL de l'aplicacio Amplify"
  value       = var.github_token != "" ? "https://main.${aws_amplify_app.cv_app[0].default_domain}" : "Amplify no configurat (falta github_token)"
  sensitive   = true
}

# -----------------------------------------------------
# Outputs de S3 (fallback)
# -----------------------------------------------------

output "frontend_bucket_name" {
  description = "Nom del bucket S3 del frontend"
  value       = aws_s3_bucket.frontend.id
}

output "frontend_website_url" {
  description = "URL del lloc web estàtic S3"
  value       = "http://${aws_s3_bucket.frontend.id}.s3-website-${var.aws_region}.amazonaws.com"
}

output "project_info" {
  description = "Informació general del projecte"
  value = {
    project_name = var.project_name
    environment  = var.environment
    aws_region   = var.aws_region
  }
}
