"""
Cloud Resume Challenge - Lambda Function
Projecte educatiu ASIX

Aquesta funció Lambda gestiona el comptador de visites:
- Incrementa el comptador a DynamoDB en cada visita
- Retorna el valor actual del comptador

Serveis AWS utilitzats:
- AWS Lambda (execució serverless)
- Amazon DynamoDB (base de dades NoSQL)
- Amazon API Gateway (endpoint REST)
"""

import json
import os
import logging
import boto3
from botocore.exceptions import ClientError
from decimal import Decimal

# Configuració del logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Inicialitzem el client de DynamoDB
# Utilitzem variables d'entorn per a la configuració
dynamodb = boto3.resource('dynamodb')
TABLE_NAME = os.environ.get('DYNAMODB_TABLE', 'cv-visites')


def decimal_to_int(obj):
    """
    Converteix objectes Decimal a int per a la serialització JSON.
    DynamoDB retorna números com a Decimal, que no són serialitzables directament.
    """
    if isinstance(obj, Decimal):
        return int(obj)
    raise TypeError(f"Object of type {type(obj)} is not JSON serializable")


def get_cors_headers():
    """
    Retorna les capçaleres CORS necessàries per permetre
    peticions des del frontend.
    """
    return {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',  # En producció, especifica el domini
        'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key',
        'Access-Control-Allow-Methods': 'GET,POST,OPTIONS'
    }


def increment_visitor_count():
    """
    Incrementa el comptador de visites a DynamoDB.
    Utilitza UpdateItem amb ADD per a operacions atòmiques.
    
    Returns:
        int: El nou valor del comptador
    """
    table = dynamodb.Table(TABLE_NAME)
    
    try:
        # Utilitzem UpdateItem amb ADD per incrementar atòmicament
        response = table.update_item(
            Key={
                'id': 'contador_principal'  # Clau primària del comptador
            },
            UpdateExpression='ADD visites :inc',
            ExpressionAttributeValues={
                ':inc': 1
            },
            ReturnValues='UPDATED_NEW'  # Retorna el nou valor
        )
        
        # Extraiem el nou valor del comptador
        new_count = response['Attributes']['visites']
        logger.info(f"Comptador actualitzat: {new_count}")
        
        return int(new_count)
        
    except ClientError as e:
        logger.error(f"Error de DynamoDB: {e.response['Error']['Message']}")
        raise


def get_visitor_count():
    """
    Obté el valor actual del comptador sense incrementar-lo.
    
    Returns:
        int: El valor actual del comptador
    """
    table = dynamodb.Table(TABLE_NAME)
    
    try:
        response = table.get_item(
            Key={
                'id': 'contador_principal'
            }
        )
        
        if 'Item' in response:
            return int(response['Item'].get('visites', 0))
        else:
            return 0
            
    except ClientError as e:
        logger.error(f"Error de DynamoDB: {e.response['Error']['Message']}")
        raise


def lambda_handler(event, context):
    """
    Funció principal que gestiona les peticions de l'API Gateway.
    
    Args:
        event: Esdeveniment d'API Gateway amb la informació de la petició
        context: Context d'execució de Lambda
    
    Returns:
        dict: Resposta HTTP amb el comptador de visites
    
    Mètodes HTTP suportats:
        - GET: Retorna el comptador sense incrementar
        - POST: Incrementa i retorna el comptador
        - OPTIONS: Gestiona preflight CORS
    """
    
    logger.info(f"Event rebut: {json.dumps(event)}")
    
    # Obtenim el mètode HTTP
    http_method = event.get('httpMethod', 'POST')
    
    # Gestió de preflight CORS
    if http_method == 'OPTIONS':
        return {
            'statusCode': 200,
            'headers': get_cors_headers(),
            'body': ''
        }
    
    try:
        if http_method == 'POST':
            # POST: Incrementem el comptador i el retornem
            count = increment_visitor_count()
            message = 'Comptador incrementat correctament'
            
        elif http_method == 'GET':
            # GET: Només obtenim el valor actual
            count = get_visitor_count()
            message = 'Comptador obtingut correctament'
            
        else:
            # Mètode no suportat
            return {
                'statusCode': 405,
                'headers': get_cors_headers(),
                'body': json.dumps({
                    'error': 'Mètode no permès',
                    'metodes_suportats': ['GET', 'POST', 'OPTIONS']
                })
            }
        
        # Resposta exitosa
        response_body = {
            'visites': count,
            'message': message
        }
        
        return {
            'statusCode': 200,
            'headers': get_cors_headers(),
            'body': json.dumps(response_body)
        }
        
    except ClientError as e:
        # Error de DynamoDB
        logger.error(f"Error de DynamoDB: {str(e)}")
        return {
            'statusCode': 500,
            'headers': get_cors_headers(),
            'body': json.dumps({
                'error': 'Error de base de dades',
                'details': str(e)
            })
        }
        
    except Exception as e:
        # Error genèric
        logger.error(f"Error inesperat: {str(e)}")
        return {
            'statusCode': 500,
            'headers': get_cors_headers(),
            'body': json.dumps({
                'error': 'Error intern del servidor',
                'details': str(e)
            })
        }


# Punt d'entrada per a testing local
if __name__ == "__main__":
    # Simulem un event de test
    test_event = {
        'httpMethod': 'POST',
        'body': json.dumps({'page': 'cv'})
    }
    
    # Executem la funció
    result = lambda_handler(test_event, None)
    print(json.dumps(result, indent=2))
