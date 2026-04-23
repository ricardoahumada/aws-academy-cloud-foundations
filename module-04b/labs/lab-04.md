# Lab 4b.4: Tracing Distribuido con CloudWatch ServiceLens y AWS X-Ray

**Duración:** 45 minutos  
**Nivel:** Avanzado  
**Servicios:** AWS X-Ray, CloudWatch ServiceLens, Lambda, API Gateway, DynamoDB, SQS

---

> **Versión mínima para ver trazabilidad de segmentos y subsegmentos**
>
> Para observar segmentos, subsegmentos custom y el service map con nodos conectados, los recursos mínimos son:
>
> | Recurso | Rol en el tracing |
> |---------|-------------------|
> | API Gateway (`POST /orders`) | Segmento raíz — propaga el `trace-id` downstream |
> | `lambda-orders` | 3 subsegmentos custom: `Validate-Input`, `DynamoDB-PutItem`, `SQS-SendMessage` |
> | DynamoDB (`Orders`) | Segmento automático via `AWSXRay.captureAWS()` — nodo en el service map |
>
> Con este mínimo se obtiene: service map con 3 nodos conectados, subsegmentos custom y captura automática de llamadas AWS.
>
> Los componentes `lambda-auth`, SQS y `lambda-notif` son opcionales para este objetivo; amplían el service map pero no son necesarios para demostrar el concepto de tracing distribuido.

---

## Objetivo del Lab

Implementar tracing distribuido en una aplicación serverless utilizando AWS X-Ray y CloudWatch ServiceLens. Al finalizar, se podrá visualizar el service map completo, identificar latency en subsegmentos específicos y correlacionar traces con logs de CloudWatch.

---

## Escenario

Una aplicación serverless está experimentando tiempos de respuesta elevados en producción. El equipo de operaciones necesita:

1. Habilitar tracing en todas las funciones Lambda
2. Configurar ServiceLens para visualizar el service map
3. Identificar el servicio específico que está causando latencia
4. Correlacionar traces con logs para debugging rápido

---

## Arquitectura de la Aplicación

```
                    [Client]
                        │
                        ▼
                ┌───────────────┐
                │  API Gateway  │
                │  (OrdersAPI)  │
                └───────┬───────┘
                        │
          POST /auth    │    POST /orders
           ┌────────────┴────────────┐
           ▼                         ▼
    ┌───────────────┐       ┌───────────────┐
    │  lambda-auth  │       │ lambda-orders │
    │  (validate)   │       │ (write order) │
    └───────────────┘       └───────┬───────┘
                                    │
                        ┌───────────┴───────────┐
                        ▼                       ▼
                ┌───────────────┐       ┌───────────────┐
                │   DynamoDB    │       │     SQS       │
                │   (Orders)    │       │ NotifQueue    │
                └───────────────┘       └───────┬───────┘
                                                │
                                                ▼
                                        ┌───────────────┐
                                        │  lambda-notif │
                                        │  (process)    │
                                        └───────────────┘
```

Flujo de tracing:
1. Client → API Gateway `OrdersAPI` (punto de entrada X-Ray)
2. `POST /auth` → lambda-auth (validación de token, solo subsegmentos internos)
3. `POST /orders` → lambda-orders → DynamoDB (escritura de pedido)
4. lambda-orders → SQS NotifQueue → lambda-notif (procesamiento asíncrono)

---

## Prerrequisitos

- Acceso a la consola de AWS con permisos para Lambda, API Gateway, X-Ray, CloudWatch
- Funciones Lambda existentes con código de aplicación
- API Gateway REST o HTTP con integración Lambda
- Permisos IAM para crear y modificar roles de ejecución Lambda
- CLI de AWS configurada con credentials

---

## Recursos Necesarios

| Recurso | Descripción |
|---------|-------------|
| 3 Funciones Lambda | lambda-auth, lambda-orders, lambda-notification |
| 1 API Gateway | REST API con integración Lambda |
| 1 DynamoDB Table | Tabla Orders para almacenar pedidos |
| 1 SQS Queue | Cola para procesamiento asíncrono de notificaciones |
| CloudWatch Log Groups | Logs de Lambda configurados |

---

## Paso a Paso

### Parte 1: Habilitar X-Ray Tracing en Lambda (Console)

1. Iniciar sesión en la consola de AWS
2. Navegar a **Lambda** > **Functions**
3. Seleccionar la función **lambda-auth**
4. Ir a la pestaña **Configuration** > **Monitoring tools**
5. En la sección **X-Ray**, hacer clic en **Edit**
6. Habilitar **Active tracing** con X-Ray
7. Hacer clic en **Save**
8. Repetir los pasos 3-7 para **lambda-orders** y **lambda-notification**

### Parte 2: Habilitar X-Ray via AWS CLI

9. Abrir terminal con AWS CLI configurada
10. Ejecutar los siguientes comandos para habilitar tracing en todas las funciones:

```bash
# Habilitar tracing en lambda-auth
aws lambda update-function-configuration \
    --function-name lambda-auth \
    --tracing-config Mode=Active

# Habilitar tracing en lambda-orders
aws lambda update-function-configuration \
    --function-name lambda-orders \
    --tracing-config Mode=Active

# Habilitar tracing en lambda-notification
aws lambda update-function-configuration \
    --function-name lambda-notification \
    --tracing-config Mode=Active

# Verificar que tracing está habilitado
aws lambda list-functions \
    --query 'Functions[*].[FunctionName,TracingConfig.Mode]' \
    --output table
```

11. Verificar que todas las funciones muestran `Active` en la columna TracingConfig.Mode

### Parte 3: Generar Trazas de Prueba

Para visualizar traces en ServiceLens, es necesario invocar el API Gateway y disparar las funciones Lambda.

12. Obtener la URL del API Gateway:

```bash
# Verificar que el API Gateway está desplegado y obtener la URL de invoke
aws apigateway get-stages \
    --rest-api-id YOUR_API_ID \
    --query 'item[0].[stageName,invokeUrl]' \
    --output text
```

Reemplazar `YOUR_API_ID` con el ID del API Gateway creado en la pre-configuración (ej: `abc123def456`).

La URL base será algo como: `https://{api-id}.execute-api.us-east-1.amazonaws.com/prod`

13. Invocar el endpoint `/orders` para generar traces en lambda-orders:

```bash
# Primera request - crear un pedido
curl -X POST \
  "https://YOUR_API_ID.execute-api.us-east-1.amazonaws.com/prod/orders" \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "user-123",
    "items": [{"name": "Widget Pro", "qty": 2, "price": 25.00}],
    "total": 50.00
  }'

# Verificar respuesta: statusCode 201 y orderId generado
```

14. Generar tráfico adicional para populate el service map:

```bash
# Invocar 5 veces con diferentes payloads para generar traces variados
for i in 1 2 3 4 5; do
  echo "Request $i..."
  curl -s -X POST \
    "https://YOUR_API_ID.execute-api.us-east-1.amazonaws.com/prod/orders" \
    -H "Content-Type: application/json" \
    -d "{
      \"userId\": \"user-$i\",
      \"items\": [{\"name\": \"Item-$i\", \"qty\": $i, \"price\": $((i*10))}],
      \"total\": $((i*15))
    }"
  sleep 1
done
```

15. Invocar el endpoint `/auth` para generar traces en lambda-auth:

```bash
# Request con token válido (Bearer token)
curl -X POST \
  "https://YOUR_API_ID.execute-api.us-east-1.amazonaws.com/prod/auth" \
  -H "Authorization: Bearer test-token-$(date +%s)" \
  -H "Content-Type: application/json"

# Request con token inválido (para ver cómo se captura el error en el trace)
curl -X POST \
  "https://YOUR_API_ID.execute-api.us-east-1.amazonaws.com/prod/auth" \
  -H "Authorization: invalid-token" \
  -H "Content-Type: application/json"
```

16. Verificar que las invocaciones generaron logs en CloudWatch:

```bash
# Monitorear logs de lambda-orders en tiempo real
aws logs tail "/aws/lambda/lambda-orders" --follow --format json

# En otra terminal, monitorear logs de lambda-auth
aws logs tail "/aws/lambda/lambda-auth" --follow --format json
```

17. Confirmar que los traces aparecen en X-Ray (validación inmediata):

```bash
# Listar traces de los últimos 5 minutos
START_TIME=$(date -d '5 minutes ago' +%s)
END_TIME=$(date +%s)

aws xray get-trace-summaries \
    --start-time $START_TIME \
    --end-time $END_TIME \
    --query 'traceSummaries[0:5].[traceId,duration,hasError]' \
    --output table
```

Si no hay resultados, esperar 1-2 minutos y repetir (X-Ray puede tardar en indexar).

---

### Parte 4: Verificar Tracing Automático (Sin SDK)

> **✅ Concepto clave:** Con **Active Tracing habilitado**, Lambda traza automáticamente todas las llamadas a servicios AWS (DynamoDB, SQS, S3, etc.) **sin necesidad de instalar el SDK de X-Ray**.
>
> **No es necesario:**
> - Instalar `aws-xray-sdk` ni `aws-xray-sdk-core`
> - Modificar el código de las funciones Lambda
> - Crear Lambda Layers para X-Ray
>
> **Lo que se traza automáticamente:**
> - Llamadas a DynamoDB (`PutCommand`, `GetCommand`, etc.)
> - Envíos a SQS (`SendMessageCommand`)
> - Operaciones en S3, SNS, Kinesis, Step Functions, etc.
> - Invocaciones de Lambda a Lambda
> - Llamadas HTTP externas (parcialmente)

18. Verificar que el código de `lambda-orders` usa **solo AWS SDK v3** (sin X-Ray SDK):

```javascript
// lambda-orders/index.mjs
import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, PutCommand } from '@aws-sdk/lib-dynamodb';
import { SQSClient, SendMessageCommand } from '@aws-sdk/client-sqs';

// ❌ NO importar aws-xray-sdk - no es necesario con Active Tracing

const client = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(client);

export const handler = async (event) => {
    let body = {};
    if (event.body) {
        body = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
    } else if (event.userId) {
        body = event;
    }
    
    try {
        const orderId = `order-${Date.now()}`;
        const timestamp = new Date().toISOString();
        
        const order = {
            orderId,
            userId: body.userId || 'user-default',
            items: body.items || [],
            total: body.total || 0,
            status: 'pending',
            createdAt: timestamp
        };
        
        // ✅ Con Active Tracing, esto se traza automáticamente como subsegmento "DynamoDB"
        await docClient.send(new PutCommand({
            TableName: process.env.ORDERS_TABLE || 'Orders',
            Item: order
        }));
        
        // ✅ Con Active Tracing, esto se traza automáticamente como subsegmento "SQS"
        if (process.env.NOTIFICATIONS_QUEUE_URL) {
            const sqs = new SQSClient({});
            await sqs.send(new SendMessageCommand({
                QueueUrl: process.env.NOTIFICATIONS_QUEUE_URL,
                MessageBody: JSON.stringify({
                    type: 'ORDER_CREATED',
                    orderId,
                    timestamp
                }),
                MessageGroupId: 'order-notifications',
                MessageDeduplicationId: orderId
            }));
        }
        
        return {
            statusCode: 201,
            body: JSON.stringify({ success: true, orderId })
        };
    } catch (err) {
        console.error('Error processing order:', err);
        throw err;
    }
};
```

19. **Verificar que NO hay import de `aws-xray-sdk`** en ninguna función Lambda

20. Generar tráfico adicional para verificar subsegmentos automáticos:

```bash
# Invocar 3 veces para generar traces con subsegmentos
for i in 1 2 3; do
  curl -s -X POST \
    "https://YOUR_API_ID.execute-api.us-east-1.amazonaws.com/prod/orders" \
    -H "Content-Type: application/json" \
    -d "{\"userId\": \"test-$i\", \"items\": [{\"name\": \"Item\"}], \"total\": 10}"
  sleep 2
done
```

21. Esperar 2-3 minutos y verificar en **CloudWatch** > **ServiceLens** > **Traces**:
    - Seleccionar un trace reciente
    - Expandir el segmento de `lambda-orders`
    - Verificar que aparecen subsegmentos **DynamoDB** y **SQS** generados automáticamente
    - Cada subsegmento mostrará: duración, tabla/cola afectada, errores (si los hay)

> **💡 Tip:** Si necesitas subsegmentos custom para medir lógica de negocio (ej: validaciones complejas, cálculos), consulta el anexo "Advanced: Custom Subsegments" al final del lab. Para el 95% de casos, el tracing automático es suficiente.

### Parte 5: Visualizar Service Map en CloudWatch

22. En la consola de AWS, navegar a **CloudWatch** > **ServiceLens** > **Service Map**
23. Esperar 5 minutos para que aparezcan los primeros datos en el service map
24. Identificar los nodos:
    - **API Gateway** (punto de entrada)
    - **lambda-auth** (autenticación)
    - **lambda-orders** (procesamiento de pedidos)
    - **lambda-notification** (notificaciones)
    - **DynamoDB** (base de datos)
    - **SQS** (cola de mensajes)
25. Verificar que las conexiones entre nodos reflejan la arquitectura real
26. Identificar nodos en color rojo (indica errores) o amarillo (alta latencia)

### Parte 6: Analizar Traces Específicos

27. Navegar a **CloudWatch** > **ServiceLens** > **Traces**
28. En el filtro de tiempo, seleccionar **Last 30 minutes**
29. Filtrar por servicio: `service("lambda-orders")`
30. Seleccionar un trace con **Duration** mayor a 2000ms
31. Hacer clic en el trace para ver los detalles
32. Identificar los subsegmentos:
    - ¿Cuál subsegmento tiene mayor latencia?
    - ¿Hay algún error en algún subsegmento?
33. Documentar los hallazgos para troubleshooting

### Parte 7: Correlacionar Trace con Logs

34. En los detalles del trace, hacer clic en **View logs**
35. Se abrirá CloudWatch Logs con el filtro `trace_id = "1-xxxxxxxx-xxxxxxxx"`
36. Analizar los logs del período del trace
37. Identificar si hay errores o advertencias que correlacionen con la latencia

### Parte 8: Crear Alarma desde X-Ray Insights

38. Navegar a **CloudWatch** > **ServiceLens** > **X-Ray Insights**
39. Hacer clic en **Create insight**
40. Configurar las condiciones del insight:

| Parámetro | Valor |
|-----------|-------|
| Name | HighLatencyAlert |
| Condition | latency > 3000 |
| Period | 5 minutes |
| Group by | service.name |

41. Hacer clic en **Next**
42. Configurar la alarma:
    - **Alarm name**: `X-Ray-HighLatency-{ServiceName}`
    - **SNS Topic**: Seleccionar topic para notificaciones
43. Hacer clic en **Create alarm**

---

## Verificación del Lab

| # | Verificación | Criterio de Éxito |
|---|--------------|-------------------|
| 1 | Tracing habilitado en Lambda | aws lambda get-function-configuration muestra TracingConfig.Mode=Active |
| 2 | Service Map muestra nodos | Al menos 4 nodos visibles (API GW, Auth, Orders, Notification) |
| 3 | Service Map muestra conexiones | Las flechas reflejan la arquitectura de la aplicación |
| 4 | Trace accesible | Seleccionar un trace y ver sus subsegmentos |
| 5 | Subsegmentos con latencia | Los subsegmentos muestran valores de duración |
| 6 | Logs filtrables por trace ID | View logs abre CloudWatch Logs con filtro correcto |
| 7 | X-Ray Insights configurado | Insight creado con condición de latencia |

---

## Comandos AWS CLI

```bash
# Habilitar tracing en Lambda
aws lambda update-function-configuration \
    --function-name lambda-orders \
    --tracing-config Mode=Active

# Listar funciones con tracing
aws lambda list-functions \
    --query 'Functions[?TracingConfig.Mode==`Active`].[FunctionName,TracingConfig.Mode]'

# Obtener traces recent
aws xray get-trace-summaries \
    --start-time 1745280000 \
    --end-time 1745283600

# Obtener detalle de un trace específico
aws xray batch-get-traces \
    --trace-ids "1-5e1b4b20-0123456789abcdef01234567"

# Crear grupo de sampling
aws xray create-group \
    --group-name "ProductionGroup" \
    --filter-expression 'service("lambda-orders") AND latency > 2000'

# Listar grupos
aws xray list-groups

# Crear sampling rule
aws xray create-sampling-rule \
    --sampling-rule '{
        "RuleName": "Default",
        "ResourceARN": "*",
        "Priority": 1,
        "FixedRate": 0.05,
        "ReservoirSize": 100,
        "ServiceName": "*",
        "ServiceType": "*",
        "Host": "*",
        "HTTPMethod": "*",
        "URLPath": "*"
    }'

# Ver reglas de sampling
aws xray list-sampling-rules
```

---

## Errores Comunes y Soluciones

| Error | Causa | Solución |
|-------|-------|----------|
| Service Map vacío | X-Ray daemon no está corriendo | Verificar que Lambda tiene permisos para X-Ray |
| Sin subsegmentos automáticos | Active Tracing no habilitado | Habilitar Active Tracing en configuración de Lambda |
| `Cannot find package 'aws-xray-sdk'` | Import innecesario del SDK | Eliminar import — Active Tracing funciona sin SDK |
| Latencia no aparece | Esperar más tiempo para datos | Esperar 5-10 minutos para primera agregación |
| Trace no muestra logs | Logs no tienen trace ID | Verificar que CloudWatch Logs está configurado |
| Permission denied | Rol de Lambda sin permisos X-Ray | Agregar policy `AWSXRayDaemonWriteAccess` al rol |

---

## Notas sobre Cambios Recientes (Abr 2026)

- **X-Ray SDK v3** ahora permite tracing automático sin modificar código para funciones Lambda con runtime Python, Node.js y Java
- **ServiceLens integrado en CloudWatch** ahora muestra automáticamente correlaciones con CloudWatch Contributor Insights
- **Nuevo endpoint X-Ray** en us-east-1 para mejor latencia en traces en tiempo real

---

## Recursos Adicionales

- [Documentación oficial AWS X-Ray](https://docs.aws.amazon.com/xray/index.html)
- [Documentación CloudWatch ServiceLens](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/ServiceLens.html)
- [AWS X-Ray SDK GitHub](https://github.com/aws/aws-xray-sdk-node)
- [X-Ray Workshop](https://catalog.workshops.aws/xray)

---

## Anexo: Subsegmentos Custom Avanzados (Opcional)

> **⚠️ Solo para casos avanzados:** Esta sección es para estudiantes que necesiten medir lógica de negocio específica que **no** sea una llamada a servicios AWS. Para el 95% de casos, el tracing automático de la Parte 4 es suficiente.

### Cuándo Usar Subsegmentos Custom

Usa subsegmentos custom SOLO para:
- Validaciones complejas de negocio (ej: validar 100+ campos)
- Algoritmos computacionales pesados (ej: cálculos matemáticos)
- Llamadas HTTP a APIs externas (no AWS)
- Procesamiento de imágenes o archivos grandes

**NO uses subsegmentos custom para:**
- Llamadas a DynamoDB, S3, SQS → ya se trazan automáticamente
- Logging simple con `console.log` → no aporta valor
- Operaciones rápidas < 10ms → ruido innecesario

### Implementación con CommonJS (Recomendado)

El SDK de X-Ray no soporta ES Modules nativamente. Usa **CommonJS** (`.cjs`) para subsegmentos custom:

```javascript
// lambda-orders/index.cjs
const AWSXRay = require('aws-xray-sdk-core');
const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { DynamoDBDocumentClient, PutCommand } = require('@aws-sdk/lib-dynamodb');
const { SQSClient, SendMessageCommand } = require('@aws-sdk/client-sqs');

const client = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(client);

exports.handler = async (event) => {
    const segment = AWSXRay.getSegment();
    
    let body = {};
    if (event.body) {
        body = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
    } else if (event.userId) {
        body = event;
    }
    
    try {
        // ✅ Subsegmento custom: Validación de negocio
        const validateSegment = segment.addNewSubsegment('Business-Validation');
        validateSegment.addAnnotation('userId', body.userId);
        validateSegment.addMetadata('items', body.items);
        
        // Simular validación compleja (ej: verificar inventario, precios, descuentos)
        if (!body.userId || !body.items || body.items.length === 0) {
            validateSegment.addError(new Error('Invalid order data'));
            validateSegment.close();
            throw new Error('Invalid order data');
        }
        validateSegment.close();
        
        const orderId = `order-${Date.now()}`;
        const timestamp = new Date().toISOString();
        
        const order = {
            orderId,
            userId: body.userId,
            items: body.items,
            total: body.total || 0,
            status: 'pending',
            createdAt: timestamp
        };
        
        // ✅ DynamoDB se traza automáticamente (no necesita subsegmento custom)
        await docClient.send(new PutCommand({
            TableName: process.env.ORDERS_TABLE || 'Orders',
            Item: order
        }));
        
        // ✅ SQS se traza automáticamente (no necesita subsegmento custom)
        if (process.env.NOTIFICATIONS_QUEUE_URL) {
            const sqs = new SQSClient({});
            await sqs.send(new SendMessageCommand({
                QueueUrl: process.env.NOTIFICATIONS_QUEUE_URL,
                MessageBody: JSON.stringify({
                    type: 'ORDER_CREATED',
                    orderId,
                    timestamp
                }),
                MessageGroupId: 'order-notifications',
                MessageDeduplicationId: orderId
            }));
        }
        
        return {
            statusCode: 201,
            body: JSON.stringify({ success: true, orderId })
        };
    } catch (err) {
        segment.addError(err);
        segment.close();
        throw err;
    }
};
```

### Crear Lambda Layer para X-Ray SDK

**Paso 1: Crear la capa localmente**
```bash
# Crear estructura de directorios
mkdir -p xray-layer/nodejs
cd xray-layer/nodejs

# Instalar dependencias
npm init -y
npm install aws-xray-sdk-core

# Crear ZIP
cd ..
zip -r xray-layer.zip nodejs/
```

**Paso 2: Publicar en AWS**
```bash
aws lambda publish-layer-version \
    --layer-name xray-sdk-core \
    --zip-file fileb://xray-layer.zip \
    --compatible-runtimes nodejs20.x nodejs22.x nodejs24.x \
    --description "AWS X-Ray SDK for custom subsegments"
```

**Paso 3: Asociar a la función**
```bash
# Obtener ARN de la layer
LAYER_ARN=$(aws lambda list-layer-versions \
    --layer-name xray-sdk-core \
    --query 'LayerVersions[0].LayerVersionArn' \
    --output text)

# Asociar a lambda-orders
aws lambda update-function-configuration \
    --function-name lambda-orders \
    --layers $LAYER_ARN
```

**Paso 4: Cambiar handler de la función**
```bash
# Si usas .cjs en lugar de .mjs
aws lambda update-function-configuration \
    --function-name lambda-orders \
    --handler index.handler
```

### Annotations vs Metadata

| Tipo | Indexado | Filtrable | Uso |
|------|----------|-----------|-----|
| **Annotation** | ✅ Sí | ✅ Sí | IDs, status codes, categorías (max 50 chars) |
| **Metadata** | ❌ No | ❌ No | Objetos complejos, payloads, debugging |

**Ejemplo:**
```javascript
const segment = AWSXRay.getSegment();
const subsegment = segment.addNewSubsegment('ProcessOrder');

// ✅ Annotation: para filtrar en ServiceLens
subsegment.addAnnotation('orderType', 'premium');
subsegment.addAnnotation('customerId', 'cust-12345');

// ✅ Metadata: para debugging (no filtrable)
subsegment.addMetadata('orderDetails', {
    items: order.items,
    paymentMethod: order.payment,
    shippingAddress: order.address
});

subsegment.close();
```

### Verificar Subsegmentos Custom en ServiceLens

1. Invocar la función con el código actualizado
2. Esperar 2-3 minutos
3. **CloudWatch** > **ServiceLens** > **Traces**
4. Seleccionar un trace reciente
5. Expandir el segmento de `lambda-orders`
6. Verificar que aparece el subsegmento `Business-Validation`
7. Click en el subsegmento para ver annotations y metadata

### Filtrar por Annotations

```bash
# Buscar traces donde orderType = 'premium'
aws xray get-trace-summaries \
    --start-time $(date -d '1 hour ago' +%s) \
    --end-time $(date +%s) \
    --filter-expression 'annotation.orderType = "premium"'
```

### Recordatorio Final

**Para la mayoría de estudiantes:**  
✅ Usar **Active Tracing** sin SDK (Parte 4) es suficiente  
❌ No necesitas subsegmentos custom para llamadas AWS  

**Solo si necesitas medir lógica de negocio:**  
✅ Usa subsegmentos custom con `.cjs` y Lambda Layer  
✅ Usa annotations para filtrar y metadata para debugging
