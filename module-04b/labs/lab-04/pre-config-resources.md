# Lab 4b.4: Pre-Configuración de Recursos

**Duración:** 30 minutos  
**Nivel:** Avanzado  
**Objetivo:** Crear la infraestructura foundation para el lab de Tracing Distribuido con CloudWatch ServiceLens y AWS X-Ray

---

## Objetivo

Este documento contiene los pasos para crear todos los recursos de infraestructura necesarios para ejecutar el Lab 4b.4 (Tracing Distribuido). Una vez completada esta pre-configuración, se puede proceder directamente al lab de tracing.

---

## Arquitectura a Crear

```
                    [Client]
                        │
                        ▼
                ┌───────────────┐
                │  API Gateway  │───▶ X-Ray (tracing)
                └───────┬───────┘
                        │
            ┌───────────┴───────────┐
            ▼                       ▼
    ┌───────────────┐       ┌───────────────┐
    │  lambda-auth  │       │ lambda-orders │
    │   (Auth)      │       │   (Orders)    │
    └───────────────┘       └───────┬───────┘
                                    │
                        ┌───────────┴───────────┐
                        ▼                       ▼
                ┌───────────────┐       ┌───────────────┐
                │   DynamoDB    │       │     SQS       │
                │  (Orders DB)  │       │NotifQueue     │
                └───────────────┘       └───────┬───────┘
                                                │
                                                ▼
                                        ┌───────────────┐
                                        │  lambda-notif │
                                        │ (Notification)│
                                        └───────────────┘
```

---

## Recursos a Crear

| Recurso | Nombre | Descripción |
|---------|--------|-------------|
| 1 Tabla DynamoDB | `Orders` | PK: `orderId` (String), SK: `userId` (String) |
| 1 Cola SQS | `NotificationsQueue` | Colas estándar para notificaciones |
| 3 Funciones Lambda | `lambda-auth`, `lambda-orders`, `lambda-notif` | Node.js 18.x |
| 1 API Gateway | `OrdersAPI` | REST API con 3 endpoints |

---

## Paso a Paso

### Parte 1: Crear Tabla DynamoDB

#### Via Console:
1. Ir a **DynamoDB** > **Tables** > **Create table**
2. Configurar:
   - **Table name**: `Orders`
   - **Partition key**: `orderId` (String)
   - **Sort key**: `userId` (String)
   - **Settings**: Default settings
3. Hacer clic en **Create table**

#### Via AWS CLI:
```bash
aws dynamodb create-table \
    --table-name Orders \
    --attribute-definitions \
        AttributeName=orderId,AttributeType=S \
        AttributeName=userId,AttributeType=S \
    --key-schema \
        AttributeName=orderId,KeyType=HASH \
        AttributeName=userId,KeyType=RANGE \
    --billing-mode PAY_PER_REQUEST
```

---

### Parte 2: Crear Cola SQS

#### Via Console:
1. Ir a **SQS** > **Queues** > **Create queue**
2. Configurar:
   - **Queue name**: `NotificationsQueue`
   - **Type**: Standard queue
   - **Configuraciónes restantes**: defaults
3. Hacer clic en **Create queue**

#### Via AWS CLI:
```bash
aws sqs create-queue \
    --queue-name NotificationsQueue \
    --attributes '{"VisibilityTimeout": "300", "MessageRetentionPeriod": "86400"}'
```

---

### Parte 3: Crear Funciones Lambda

#### 3.1 lambda-auth

**Via Console:**
1. Ir a **Lambda** > **Create function**
2. Configurar:
   - **Function name**: `lambda-auth`
   - **Runtime**: Node.js 18.x
   - **Architecture**: x86_64
   - **Permissions**: Create a new role with basic Lambda permissions
3. Hacer clic en **Create function**
4. Reemplazar el código con:

```javascript
// lambda-auth/index.js
const AWSXRay = require('aws-xray-sdk');

exports.handler = async (event) => {
    const segment = AWSXRay.getSegment();
    
    // Validar token de autorización (simulado)
    const authHeader = event.headers?.Authorization || event.authorizationToken;
    
    const subsegment = segment.addNewSubsegment('Validate-Token');
    
    try {
        // Simulación de validación
        const isValid = authHeader && authHeader.startsWith('Bearer ');
        
        if (!isValid) {
            subsegment.close(new Error('Invalid token'));
            return {
                statusCode: 401,
                body: JSON.stringify({ error: 'Unauthorized' })
            };
        }
        
        subsegment.close();
        
        return {
            statusCode: 200,
            body: JSON.stringify({
                userId: 'user-123',
                tenant: 'acme-corp',
                authorized: true
            })
        };
    } catch (err) {
        subsegment.close(err);
        throw err;
    }
};
```

5. Configurar variable de entorno:
   - **ORDERS_API_URL**: copiar el URL del API Gateway (ej: `https://abc123.execute-api.us-east-1.amazonaws.com/prod`)
6. Hacer clic en **Deploy**

**Via AWS CLI:**
```bash
# Crear archivo ZIP
cat > lambda-auth/index.js << 'EOF'
const AWSXRay = require('aws-xray-sdk');

exports.handler = async (event) => {
    const segment = AWSXRay.getSegment();
    const authHeader = event.headers?.Authorization || event.authorizationToken;
    
    const subsegment = segment.addNewSubsegment('Validate-Token');
    
    try {
        const isValid = authHeader && authHeader.startsWith('Bearer ');
        
        if (!isValid) {
            subsegment.close(new Error('Invalid token'));
            return { statusCode: 401, body: JSON.stringify({ error: 'Unauthorized' }) };
        }
        
        subsegment.close();
        
        return { statusCode: 200, body: JSON.stringify({ userId: 'user-123', tenant: 'acme-corp', authorized: true }) };
    } catch (err) {
        subsegment.close(err);
        throw err;
    }
};
EOF

cd lambda-auth && zip -r ../lambda-auth.zip index.js && cd ..
aws lambda create-function \
    --function-name lambda-auth \
    --runtime nodejs18.x \
    --handler index.handler \
    --zip-file fileb://lambda-auth.zip \
    --role arn:aws:iam::123456789012:role/lambda-basic-role \
    --tracing-config Mode=Active
```

#### 3.2 lambda-orders

**Código:**
```javascript
// lambda-orders/index.js
const AWSXRay = require('aws-xray-sdk');
const AWS = AWSXRay.captureAWS(require('aws-sdk'));
const docClient = new AWS.DynamoDB.DocumentClient();

const ORDERS_TABLE = process.env.ORDERS_TABLE || 'Orders';
const NOTIFICATIONS_QUEUE_URL = process.env.NOTIFICATIONS_QUEUE_URL;

exports.handler = async (event) => {
    const segment = AWSXRay.getSegment();
    
    // Subsegmento: Validación de input
    const validateSegment = segment.addNewSubsegment('Validate-Input');
    const body = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
    validateSegment.close();
    
    // Subsegmento: Query a DynamoDB
    const dynamoSegment = segment.addNewSubsegment('DynamoDB-PutItem');
    
    try {
        const orderId = `order-${Date.now()}`;
        const timestamp = new Date().toISOString();
        
        const order = {
            orderId,
            userId: body.userId || 'user-123',
            items: body.items || [],
            total: body.total || 0,
            status: 'pending',
            createdAt: timestamp
        };
        
        await docClient.put({
            TableName: ORDERS_TABLE,
            Item: order
        }).promise();
        
        dynamoSegment.close();
        
        // Enviar a SQS para notificación asíncrona
        if (NOTIFICATIONS_QUEUE_URL) {
            const sqsSegment = segment.addNewSubsegment('SQS-SendMessage');
            const sqs = new AWS.SQS();
            
            await sqs.sendMessage({
                QueueUrl: NOTIFICATIONS_QUEUE_URL,
                MessageBody: JSON.stringify({
                    type: 'ORDER_CREATED',
                    orderId,
                    userId: order.userId,
                    timestamp
                })
            }).promise();
            
            sqsSegment.close();
        }
        
        return {
            statusCode: 201,
            body: JSON.stringify({ success: true, orderId, order })
        };
    } catch (err) {
        dynamoSegment.close(err);
        
        if (err.code === 'ConditionalCheckFailedException') {
            return { statusCode: 409, body: JSON.stringify({ error: 'Order already exists' }) };
        }
        
        throw err;
    }
};
```

**Variables de entorno necesarias:**
- `ORDERS_TABLE`: `Orders`
- `NOTIFICATIONS_QUEUE_URL`: URL de la cola SQS creada (ej: `https://sqs.us-east-1.amazonaws.com/123456789012/NotificationsQueue`)

#### 3.3 lambda-notif

**Código:**
```javascript
// lambda-notif/index.js
const AWSXRay = require('aws-xray-sdk');
const AWS = AWSXRay.captureAWS(require('aws-sdk'));
const sqs = new AWS.SQS();

const NOTIFICATIONS_QUEUE_URL = process.env.NOTIFICATIONS_QUEUE_URL;

exports.handler = async (event) => {
    const segment = AWSXRay.getSegment();
    
    // Este handler recibe mensajes de SQS (triggers)
    const messages = event.Records || [];
    
    const processSegment = segment.addNewSubsegment('Process-Messages');
    
    let processedCount = 0;
    let errorCount = 0;
    
    for (const record of messages) {
        try {
            const message = JSON.parse(record.body);
            
            // Simular procesamiento de notificación
            console.log(`Processing notification: ${message.type} for order ${message.orderId}`);
            
            // Aquí iría lógica de envío de email, SMS, push notification, etc.
            // Por ahora solo simulamos un delay de 50ms
            await new Promise(resolve => setTimeout(resolve, 50));
            
            processedCount++;
        } catch (err) {
            console.error('Error processing message:', err);
            errorCount++;
        }
    }
    
    processSegment.close();
    
    return {
        statusCode: 200,
        body: JSON.stringify({
            processed: processedCount,
            errors: errorCount
        })
    };
};
```

**Variables de entorno necesarias:**
- `NOTIFICATIONS_QUEUE_URL`: URL de la cola SQS

**Trigger SQS:**
- Agregar trigger: **SQS** > seleccionar `NotificationsQueue`
- Batch size: 10

---

### Parte 4: Crear API Gateway

#### Via Console:

1. Ir a **API Gateway** > **Create API** > **REST API** > **Build**
2. Configurar:
   - **API name**: `OrdersAPI`
   - **Endpoint type**: Regional
3. Hacer clic en **Create API**

4. **Crear recurso /auth:**
   - En Resources > Actions > Create Resource
   - **Resource name**: `auth`
   - **Resource path**: `auth`
   - Hacer clic en **Create Resource**

5. **Crear método POST /auth:**
   - Seleccionar recurso `/auth` > Actions > Create Method > **POST**
   - Integration type: **Lambda Function**
   - **Lambda function**: `lambda-auth`
   - Hacer clic en **OK**

6. **Crear recurso /orders:**
   - En Resources > Actions > Create Resource
   - **Resource name**: `orders`
   - **Resource path**: `orders`
   - Hacer clic en **Create Resource**

7. **Crear método POST /orders:**
   - Seleccionar `/orders` > Actions > Create Method > **POST**
   - Integration type: **Lambda Function**
   - **Lambda function**: `lambda-orders`
   - Hacer clic en **OK**

8. **Habilitar CORS:**
   - En `/orders` > Actions > Enable CORS
   - Accept defaults > **Deploy**

9. **Desplegar API:**
   - Actions > Deploy API
   - **Stage**: `prod`
   - **Deployment description**: `Initial deployment`

10. **Copiar URL del API Gateway:**
    - En Stages > prod > **Invoke URL**
    - Debe verse algo como: `https://abc123.execute-api.us-east-1.amazonaws.com/prod`

#### Via AWS CLI:

```bash
# Crear API Gateway
aws apigateway create-rest-api \
    --name OrdersAPI \
    --description "API for Orders processing with X-Ray tracing"

API_ID=$(aws apigateway get-rest-apis --query 'items[0].id' --output text)
echo "API ID: $API_ID"

# Crear recurso /auth
ROOT_RESOURCE_ID=$(aws apigateway get-resources --rest-api-id $API_ID --query 'items[0].id' --output text)

aws apigateway create-resource \
    --rest-api-id $API_ID \
    --parent-id $ROOT_RESOURCE_ID \
    --path-part auth

AUTH_RESOURCE_ID=$(aws apigateway get-resources --rest-api-id $API_ID --query "items[?pathPart=='auth'].id" --output text)

# Crear método POST /auth
aws apigateway put-method \
    --rest-api-id $API_ID \
    --resource-id $AUTH_RESOURCE_ID \
    --http-method POST \
    --authorization-type NONE

aws apigateway put-integration \
    --rest-api-id $API_ID \
    --resource-id $AUTH_RESOURCE_ID \
    --http-method POST \
    --integration-http-method POST \
    --type AWS_PROXY \
    --uri arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:123456789012:function:lambda-auth/invocations

# Crear recurso /orders
aws apigateway create-resource \
    --rest-api-id $API_ID \
    --parent-id $ROOT_RESOURCE_ID \
    --path-part orders

ORDERS_RESOURCE_ID=$(aws apigateway get-resources --rest-api-id $API_ID --query "items[?pathPart=='orders'].id" --output text)

# Crear método POST /orders
aws apigateway put-method \
    --rest-api-id $API_ID \
    --resource-id $ORDERS_RESOURCE_ID \
    --http-method POST \
    --authorization-type NONE

aws apigateway put-integration \
    --rest-api-id $API_ID \
    --resource-id $ORDERS_RESOURCE_ID \
    --http-method POST \
    --integration-http-method POST \
    --type AWS_PROXY \
    --uri arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:123456789012:function:lambda-orders/invocations

# Desplegar
aws apigateway create-deployment \
    --rest-api-id $API_ID \
    --stage-name prod \
    --description "Initial deployment"

# Dar permisos a API Gateway para invocar Lambda
aws lambda add-permission \
    --function-name lambda-auth \
    --statement-id apigateway-auth \
    --action lambda:InvokeFunction \
    --principal apigateway.amazonaws.com \
    --source-arn "arn:aws:apigateway:us-east-1:*:restapis/${API_ID}/methods/POST"

aws lambda add-permission \
    --function-name lambda-orders \
    --statement-id apigateway-orders \
    --action lambda:InvokeFunction \
    --principal apigateway.amazonaws.com \
    --source-arn "arn:aws:apigateway:us-east-1:*:restapis/${API_ID}/methods/POST"
```

---

### Parte 5: Configurar Permisos IAM

Las funciones Lambda necesitan permisos para:

1. **lambda-auth**: Sin permisos especiales (no accede a otros servicios)
2. **lambda-orders**: Acceso a DynamoDB (Orders) y SQS (NotificationsQueue)
3. **lambda-notif**: Acceso a SQS (NotificationsQueue)

**Política para lambda-orders:**
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "dynamodb:PutItem",
                "dynamodb:GetItem",
                "dynamodb:Query",
                "dynamodb:Scan"
            ],
            "Resource": "arn:aws:dynamodb:us-east-1:123456789012:table/Orders"
        },
        {
            "Effect": "Allow",
            "Action": [
                "sqs:SendMessage",
                "sqs:ReceiveMessage",
                "sqs:DeleteMessage"
            ],
            "Resource": "arn:aws:sqs:us-east-1:123456789012:NotificationsQueue"
        }
    ]
}
```

**Política para lambda-notif:**
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "sqs:ReceiveMessage",
                "sqs:DeleteMessage",
                "sqs:GetQueueAttributes"
            ],
            "Resource": "arn:aws:sqs:us-east-1:123456789012:NotificationsQueue"
        }
    ]
}
```

---

### Parte 6: Verificar Recursos Creados

```bash
# Verificar DynamoDB
aws dynamodb describe-table --table-name Orders

# Verificar SQS
aws sqs get-queue-url --queue-name NotificationsQueue

# Verificar Lambdas
aws lambda list-functions --query 'Functions[*].[FunctionName,Runtime]'

# Verificar API Gateway
aws apigateway get-rest-apis
```

---

## Resumen de URLs y ARNs

| Recurso | Identificador |
|---------|---------------|
| API Gateway URL | `https://{api-id}.execute-api.us-east-1.amazonaws.com/prod` |
| Orders Table ARN | `arn:aws:dynamodb:us-east-1:{account}:table/Orders` |
| SQS Queue URL | `https://sqs.us-east-1.amazonaws.com/{account}/NotificationsQueue` |
| Lambda Auth ARN | `arn:aws:lambda:us-east-1:{account}:function:lambda-auth` |
| Lambda Orders ARN | `arn:aws:lambda:us-east-1:{account}:function:lambda-orders` |
| Lambda Notif ARN | `arn:aws:lambda:us-east-1:{account}:function:lambda-notif` |

---

## Cleanup (Limpieza Post-Lab)

Para eliminar todos los recursos creados:

```bash
# Eliminar Lambda functions
aws lambda delete-function --function-name lambda-auth
aws lambda delete-function --function-name lambda-orders
aws lambda delete-function --function-name lambda-notif

# Eliminar API Gateway
aws apigateway delete-rest-api --rest-api-id {api-id}

# Eliminar SQS queue
aws sqs delete-queue --queue-url https://sqs.us-east-1.amazonaws.com/{account}/NotificationsQueue

# Eliminar DynamoDB table
aws dynamodb delete-table --table-name Orders
```

---

## Siguiente Paso

Una vez completada esta pre-configuración, proseguir con **Lab 4b.4: Tracing Distribuido con CloudWatch ServiceLens y AWS X-Ray** (`lab-04.md`).