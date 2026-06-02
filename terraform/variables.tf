# =====================================================
# Cloud CV Mallorca - Variables de Terraform
# =====================================================

variable "project_name" {
  description = "Nom del projecte"
  type        = string
  default     = "cloud-cv-mallorca"
}

variable "environment" {
  description = "Entorn de desplegament"
  type        = string
  default     = "prod"
}

variable "aws_account_id" {
  description = "ID del compte AWS"
  type        = string
  default     = ""
}

variable "aws_region" {
  description = "Regió d'AWS"
  type        = string
  default     = "us-east-1"
}

variable "github_repository" {
  description = "URL del repositori GitHub"
  type        = string
  default     = ""
}

variable "github_token" {
  description = "Token d'accés personal de GitHub per a Amplify"
  type        = string
  sensitive   = true
  default     = ""
}

variable "lambda_timeout" {
  description = "Timeout de Lambda en segons"
  type        = number
  default     = 10
}

variable "lambda_memory" {
  description = "Memòria de Lambda en MB"
  type        = number
  default     = 128
}

variable "log_retention_days" {
  description = "Dies de retenció de logs"
  type        = number
  default     = 14
}

variable "additional_tags" {
  description = "Tags addicionals"
  type        = map(string)
  default     = {}
}
