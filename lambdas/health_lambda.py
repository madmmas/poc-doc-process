import json
import boto3
import os
from datetime import datetime, timezone

# Get DynamoDB endpoint - LocalStack Lambda functions need to connect to LocalStack service
# Try multiple approaches for LocalStack compatibility
dynamodb_endpoint = os.environ.get('DYNAMODB_ENDPOINT')
if not dynamodb_endpoint:
    # Try to construct endpoint from LocalStack hostname
    localstack_hostname = os.environ.get('LOCALSTACK_HOSTNAME', 'localstack')
    dynamodb_endpoint = f'http://{localstack_hostname}:4566'

# Create DynamoDB resource with explicit endpoint for LocalStack
dynamodb = boto3.resource(
    'dynamodb',
    endpoint_url=dynamodb_endpoint,
    region_name=os.environ.get('AWS_DEFAULT_REGION', 'us-east-1'),
    aws_access_key_id=os.environ.get('AWS_ACCESS_KEY_ID', 'test'),
    aws_secret_access_key=os.environ.get('AWS_SECRET_ACCESS_KEY', 'test')
)

table_name = os.environ.get('HEALTH_TABLE_NAME', 'health-check-table')
table = dynamodb.Table(table_name)

# Store endpoint for use in responses
ENDPOINT_URL = dynamodb_endpoint

def lambda_handler(event, context):
    """
    Health check Lambda function that reads/writes to DynamoDB.
    """
    try:
        # Write current timestamp to DynamoDB
        timestamp = datetime.now(timezone.utc).isoformat()
        table.put_item(
            Item={
                'id': 'health-check',
                'timestamp': timestamp,
                'status': 'healthy'
            }
        )
        
        # Read back from DynamoDB to verify connectivity
        response = table.get_item(
            Key={
                'id': 'health-check'
            }
        )
        
        if 'Item' in response:
            db_status = 'connected'
            last_check = response['Item'].get('timestamp', 'unknown')
        else:
            db_status = 'no_data'
            last_check = 'unknown'
        
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'status': 'healthy',
                'database': db_status,
                'timestamp': timestamp,
                'last_check': last_check,
                'service': 'api-gateway-lambda-dynamodb',
                'endpoint': ENDPOINT_URL
            })
        }
    except Exception as e:
        import traceback
        error_details = {
            'status': 'unhealthy',
            'error': str(e),
            'error_type': type(e).__name__,
            'service': 'api-gateway-lambda-dynamodb',
            'endpoint': ENDPOINT_URL,
            'table_name': table_name
        }
        # Include traceback in debug mode
        if os.environ.get('DEBUG', 'false').lower() == 'true':
            error_details['traceback'] = traceback.format_exc()
        
        return {
            'statusCode': 503,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps(error_details)
        }
