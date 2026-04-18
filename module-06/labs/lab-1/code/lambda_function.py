import json

# Sample data (replace with DynamoDB in production)
USERS = [
    {'id': '1', 'name': 'Juan Pérez', 'email': 'juan@example.com'},
    {'id': '2', 'name': 'María García', 'email': 'maria@example.com'},
    {'id': '3', 'name': 'Carlos López', 'email': 'carlos@example.com'}
]

def lambda_handler(event, context):
    """
    AWS Lambda handler for GET /users API
    
    Expected event structure from API Gateway:
    {
        'httpMethod': 'GET',
        'path': '/users' or '/users/{id}',
        'pathParameters': {'id': '123'}  (optional)
    }
    """
    # Get HTTP method
    http_method = event.get('httpMethod', 'GET')
    
    # Get path
    path = event.get('path', '/')
    
    # Route handling
    if http_method == 'GET' and path == '/users':
        return {
            'statusCode': 200,
            'body': json.dumps({'users': USERS, 'count': len(USERS)}),
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            }
        }
    
    elif http_method == 'GET' and path.startswith('/users/'):
        user_id = path.split('/')[-1]
        user = next((u for u in USERS if u['id'] == user_id), None)
        
        if user:
            return {
                'statusCode': 200,
                'body': json.dumps(user),
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                }
            }
        
        return {
            'statusCode': 404,
            'body': json.dumps({'error': 'User not found', 'user_id': user_id}),
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            }
        }
    
    # CORS preflight
    elif http_method == 'OPTIONS':
        return {
            'statusCode': 200,
            'headers': {
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type',
                'Access-Control-Allow-Methods': 'GET, OPTIONS'
            },
            'body': ''
        }
    
    else:
        return {
            'statusCode': 400,
            'body': json.dumps({'error': 'Invalid request', 'path': path, 'method': http_method}),
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            }
        }
