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

### Parte 4: Agregar Subsegmentos Personalizados (Opcional)

18. Para mejorar el tracing, agregar el SDK de X-Ray en las funciones Lambda:

```javascript
// Ejemplo: lambda-orders/index.js
const AWSXRay = require('aws-xray-sdk');
const AWS = AWSXRay.captureAWS(require('aws-sdk'));

exports.handler = async (event) => {
    // Obtener el segmento actual
    const segment = AWSXRay.getSegment();
    
    // Subsegmento para llamada a DynamoDB
    const dynamoSubsegment = segment.addNewSubsegment('DynamoDB-GetItem');
    
    try {
        // Llamada a DynamoDB
        const result = await dynamodb.getItem({
            TableName: process.env.ORDERS_TABLE,
            Key: { orderId: event.pathParameters.orderId }
        }).promise();
        
        dynamoSubsegment.close();
        return result;
    } catch (err) {
        dynamoSubsegment.close(err);
        throw err;
    }
};
```

19. Recargar el código de las funciones Lambda si se realizan cambios

### Parte 5: Visualizar Service Map en CloudWatch

19. En la consola de AWS, navegar a **CloudWatch** > **ServiceLens** > **Service Map**
20. Esperar 5 minutos para que aparezcan los primeros datos en el service map
21. Identificar los nodos:
    - **API Gateway** (punto de entrada)
    - **lambda-auth** (autenticación)
    - **lambda-orders** (procesamiento de pedidos)
    - **lambda-notification** (notificaciones)
    - **DynamoDB** (base de datos)
    - **SQS** (cola de mensajes)
22. Verificar que las conexiones entre nodos reflejan la arquitectura real
23. Identificar nodos en color rojo (indica errores) o amarillo (alta latencia)

### Parte 6: Analizar Traces Específicos

24. Navegar a **CloudWatch** > **ServiceLens** > **Traces**
25. En el filtro de tiempo, seleccionar **Last 30 minutes**
26. Filtrar por servicio: `service("lambda-orders")`
27. Seleccionar un trace con **Duration** mayor a 2000ms
28. Hacer clic en el trace para ver los detalles
29. Identificar los subsegmentos:
    - ¿Cuál subsegmento tiene mayor latencia?
    - ¿Hay algún error en algún subsegmento?
30. Documentar los hallazgos para troubleshooting

### Parte 7: Correlacionar Trace con Logs

31. En los detalles del trace, hacer clic en **View logs**
32. Se abrirá CloudWatch Logs con el filtro `trace_id = "1-xxxxxxxx-xxxxxxxx"`
33. Analizar los logs del período del trace
34. Identificar si hay errores o advertencias que correlacionen con la latencia

### Parte 8: Crear Alarma desde X-Ray Insights

35. Navegar a **CloudWatch** > **ServiceLens** > **X-Ray Insights**
36. Hacer clic en **Create insight**
37. Configurar las condiciones del insight:

| Parámetro | Valor |
|-----------|-------|
| Name | HighLatencyAlert |
| Condition | latency > 3000 |
| Period | 5 minutes |
| Group by | service.name |

38. Hacer clic en **Next**
39. Configurar la alarma:
    - **Alarm name**: `X-Ray-HighLatency-{ServiceName}`
    - **SNS Topic**: Seleccionar topic para notificaciones
40. Hacer clic en **Create alarm**

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
| Sin subsegmentos | Falta AWS X-Ray SDK en el código | Agregar `aws-xray-sdk-core` como dependency |
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
