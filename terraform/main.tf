terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}

# =====================================================
# DATA SOURCES
# =====================================================

data "aws_region" "current" {}

data "aws_iam_role" "lambda_role" {
  name = "LabRole"
}

# =====================================================
# DYNAMODB - Base de dades per al comptador
# =====================================================

resource "aws_dynamodb_table" "visitor_counter" {
  name         = "${var.project_name}-visites"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }

  tags = {
    Name = "${var.project_name}-dynamodb-table"
  }
}

resource "aws_dynamodb_table_item" "initial_counter" {
  table_name = aws_dynamodb_table.visitor_counter.name
  hash_key   = aws_dynamodb_table.visitor_counter.hash_key

  item = <<ITEM
{
  "id": {"S": "contador_principal"},
  "visites": {"N": "0"}
}
ITEM

  lifecycle {
    ignore_changes = [item]
  }
}

# =====================================================
# LAMBDA - Funció serverless
# =====================================================

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/../backend/lambda_function.py"
  output_path = "${path.module}/lambda_function.zip"
}

resource "aws_lambda_function" "visitor_counter" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "${var.project_name}-counter"
  role             = data.aws_iam_role.lambda_role.arn
  handler          = "lambda_function.lambda_handler"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime          = "python3.11"
  timeout          = 10
  memory_size      = 128

  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.visitor_counter.name
    }
  }

  tags = {
    Name = "${var.project_name}-lambda"
  }
}

resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.visitor_counter.function_name}"
  retention_in_days = 14

  tags = {
    Name = "${var.project_name}-lambda-logs"
  }
}

# =====================================================
# API GATEWAY - Endpoint REST
# =====================================================

resource "aws_api_gateway_rest_api" "cv_api" {
  name        = "${var.project_name}-api"
  description = "API per al comptador de visites del CV"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = {
    Name = "${var.project_name}-api-gateway"
  }
}

resource "aws_api_gateway_resource" "visites" {
  rest_api_id = aws_api_gateway_rest_api.cv_api.id
  parent_id   = aws_api_gateway_rest_api.cv_api.root_resource_id
  path_part   = "visites"
}

resource "aws_api_gateway_method" "post_visites" {
  rest_api_id   = aws_api_gateway_rest_api.cv_api.id
  resource_id   = aws_api_gateway_resource.visites.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "get_visites" {
  rest_api_id   = aws_api_gateway_rest_api.cv_api.id
  resource_id   = aws_api_gateway_resource.visites.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "options_visites" {
  rest_api_id   = aws_api_gateway_rest_api.cv_api.id
  resource_id   = aws_api_gateway_resource.visites.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "post_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.cv_api.id
  resource_id             = aws_api_gateway_resource.visites.id
  http_method             = aws_api_gateway_method.post_visites.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.visitor_counter.invoke_arn
}

resource "aws_api_gateway_integration" "get_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.cv_api.id
  resource_id             = aws_api_gateway_resource.visites.id
  http_method             = aws_api_gateway_method.get_visites.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.visitor_counter.invoke_arn
}

resource "aws_api_gateway_integration" "options_mock" {
  rest_api_id = aws_api_gateway_rest_api.cv_api.id
  resource_id = aws_api_gateway_resource.visites.id
  http_method = aws_api_gateway_method.options_visites.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "options_200" {
  rest_api_id = aws_api_gateway_rest_api.cv_api.id
  resource_id = aws_api_gateway_resource.visites.id
  http_method = aws_api_gateway_method.options_visites.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }

  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_integration_response" "options_response" {
  rest_api_id = aws_api_gateway_rest_api.cv_api.id
  resource_id = aws_api_gateway_resource.visites.id
  http_method = aws_api_gateway_method.options_visites.http_method
  status_code = aws_api_gateway_method_response.options_200.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,POST,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
}

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.visitor_counter.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.cv_api.execution_arn}/*/*"
}

resource "aws_api_gateway_deployment" "cv_deployment" {
  depends_on = [
    aws_api_gateway_integration.post_lambda,
    aws_api_gateway_integration.get_lambda,
    aws_api_gateway_integration.options_mock,
  ]

  rest_api_id = aws_api_gateway_rest_api.cv_api.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.visites.id,
      aws_api_gateway_method.post_visites.id,
      aws_api_gateway_method.get_visites.id,
      aws_api_gateway_integration.post_lambda.id,
      aws_api_gateway_integration.get_lambda.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "prod" {
  deployment_id = aws_api_gateway_deployment.cv_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.cv_api.id
  stage_name    = "prod"

  tags = {
    Name = "${var.project_name}-api-stage-prod"
  }
}

# =====================================================
# AWS AMPLIFY - Hosting del frontend
# =====================================================

resource "aws_amplify_app" "cv_app" {
  count = var.github_token != "" ? 1 : 0

  name       = var.project_name
  repository = var.github_repository

  access_token = var.github_token

  build_spec = <<-EOT
    version: 1
    frontend:
      phases:
        build:
          commands:
            - echo "No build needed for static HTML"
      artifacts:
        baseDirectory: frontend
        files:
          - '**/*'
      cache:
        paths: []
  EOT

  environment_variables = {
    API_ENDPOINT = "${aws_api_gateway_stage.prod.invoke_url}/visites"
  }

  custom_rule {
    source = "/<*>"
    status = "404"
    target = "/index.html"
  }

  tags = {
    Name = "${var.project_name}-amplify"
  }
}

resource "aws_amplify_branch" "main" {
  count = var.github_token != "" ? 1 : 0

  app_id      = aws_amplify_app.cv_app[0].id
  branch_name = "main"

  framework = "Web"
  stage     = "PRODUCTION"

  enable_auto_build = true

  environment_variables = {
    API_ENDPOINT = "${aws_api_gateway_stage.prod.invoke_url}/visites"
  }
}

# =====================================================
# S3 STATIC WEBSITE - Frontend alternatiu (fallback)
# =====================================================

resource "aws_s3_bucket" "frontend" {
  bucket = "${lower(var.project_name)}-frontend-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name = "${var.project_name}-frontend-s3"
  }
}

resource "aws_s3_bucket_website_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html"
  }
}

resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.frontend.arn}/*"
      }
    ]
  })
}

resource "aws_s3_object" "index_html" {
  bucket       = aws_s3_bucket.frontend.id
  key          = "index.html"
  source       = "${path.module}/../frontend/index.html"
  content_type = "text/html"
  etag         = filemd5("${path.module}/../frontend/index.html")
}

resource "aws_s3_object" "style_css" {
  bucket       = aws_s3_bucket.frontend.id
  key          = "css/style.css"
  source       = "${path.module}/../frontend/css/style.css"
  content_type = "text/css"
  etag         = filemd5("${path.module}/../frontend/css/style.css")
}

resource "aws_s3_object" "counter_js" {
  bucket       = aws_s3_bucket.frontend.id
  key          = "js/counter.js"
  source       = "${path.module}/../frontend/js/counter.js"
  content_type = "application/javascript"
  etag         = filemd5("${path.module}/../frontend/js/counter.js")
}
