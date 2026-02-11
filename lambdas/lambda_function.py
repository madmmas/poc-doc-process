import json

def lambda_handler(event, context):
    """
    Simple Lambda function that returns a greeting message.
    """
    # Extract query parameters or use defaults
    name = event.get('queryStringParameters', {}).get('name', 'World') if event.get('queryStringParameters') else 'World'
    
    response = {
        'statusCode': 200,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*'
        },
        'body': json.dumps({
            'message': f'Hello, {name}!',
            'event': event
        })
    }
    
    return response
