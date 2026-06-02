# Cloud CV Mallorca

> Currículum Vitae online desplegat a AWS amb arquitectura serverless i Amplify.

## URLs

| Recurs | URL |
|--------|-----|
| **Amplify** | `https://main.<app-id>.amplifyapp.com` |
| **API Gateway** | `https://<api-id>.execute-api.us-east-1.amazonaws.com/prod/visites` |

## Arquitectura

```
GitHub (repo públic)
  └─→ AWS Amplify (hosting + CI/CD)
       └─→ API Gateway
            └─→ Lambda (Python)
                 └─→ DynamoDB (comptador)
```

## Desplegament

```bash
# 1. Inicialitza el backend de Terraform
./init.sh

# 2. Configura terraform.tfvars
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# Omple github_token amb el teu token

# 3. Desplega
cd terraform
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

## Provar l'API

```bash
# GET
curl https://<API_ID>.execute-api.us-east-1.amazonaws.com/prod/visites

# POST (incrementa el comptador)
curl -X POST https://<API_ID>.execute-api.us-east-1.amazonaws.com/prod/visites \
  -H "Content-Type: application/json" -d '{}'
```
