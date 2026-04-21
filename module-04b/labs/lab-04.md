# Lab 4b.4: Tracing Distribuido con CloudWatch ServiceLens y AWS X-Ray

**Duración:** 45 minutos  
**Nivel:** Avanzado  
**Servicios:** AWS X-Ray, CloudWatch ServiceLens, Lambda, API Gateway, DynamoDB, SQS

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
                └───────┬───────┘
                        │
            ┌───────────┴───────────┐
            ▼                       ▼
    ┌───────────────┐       ┌───────────────┐
    │  lambda-auth  │       │ lambda-orders │
    │   (Auth)      │       │   (Orders)    │
    └───────┬───────┘       └───────┬───────┘
            │                       │
            └───────────┬───────────┘
                        ▼
                ┌───────────────┐
                │   DynamoDB    │
                │  (Orders DB)  │
                └───────────────┘
                        │
                        ▼
                ┌───────────────┐
                │lambda-notif   │
                │ (Notification)│
                └───────┬───────┘
                        │
                        ▼
                ┌───────────────┐
                │     SQS       │
                │   (Queue)     │
                └───────────────┘
```

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

### Parte 3: Agregar Subsegmentos Personalizados (Opcional)

12. Para mejorar el tracing, agregar el SDK de X-Ray en las funciones Lambda:

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

13. Recargar el código de las funciones Lambda si se realizan cambios

### Parte 4: Visualizar Service Map en CloudWatch

14. En la consola de AWS, navegar a **CloudWatch** > **ServiceLens** > **Service Map**
15. Esperar 5 minutos para que aparezcan los primeros datos en el service map
16. Identificar los nodos:
    - **API Gateway** (punto de entrada)
    - **lambda-auth** (autenticación)
    - **lambda-orders** (procesamiento de pedidos)
    - **lambda-notification** (notificaciones)
    - **DynamoDB** (base de datos)
    - **SQS** (cola de mensajes)
17. Verificar que las conexiones entre nodos reflejan la arquitectura real
18. Identificar nodos en color rojo (indica errores) o amarillo (alta latencia)

### Parte 5: Analizar Traces Específicos

19. Navegar a **CloudWatch** > **ServiceLens** > **Traces**
20. En el filtro de tiempo, seleccionar **Last 30 minutes**
21. Filtrar por servicio: `service("lambda-orders")`
22. Seleccionar un trace con **Duration** mayor a 2000ms
23. Hacer clic en el trace para ver los detalles
24. Identificar los subsegmentos:
    - ¿Cuál subsegmento tiene mayor latencia?
    - ¿Hay algún error en algún subsegmento?
25. Documentar los hallazgos para troubleshooting

### Parte 6: Correlacionar Trace con Logs

26. En los detalles del trace, hacer clic en **View logs**
27. Se abrirá CloudWatch Logs con el filtro `trace_id = "1-xxxxxxxx-xxxxxxxx"`
28. Analizar los logs del período del trace
29. Identificar si hay errores o advertencias que correlacionen con la latencia

### Parte 7: Crear Alarma desde X-Ray Insights

30. Navegar a **CloudWatch** > **ServiceLens** > **X-Ray Insights**
31. Hacer clic en **Create insight**
32. Configurar las condiciones del insight:

| Parámetro | Valor |
|-----------|-------|
| Name | HighLatencyAlert |
| Condition | latency > 3000 |
| Period | 5 minutes |
| Group by | service.name |

33. Hacer clic en **Next**
34. Configurar la alarma:
    - **Alarm name**: `X-Ray-HighLatency-{ServiceName}`
    - **SNS Topic**: Seleccionar topic para notificaciones
35. Hacer clic en **Create alarm**

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
    --start-time 1713600000 \
    --end-time 1713603600

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

## Notas sobre Cambios Recientes (Feb 2026)

- **X-Ray SDK v3** ahora permite tracing automático sin modificar código para funciones Lambda con runtime Python, Node.js y Java
- **ServiceLens integrado en CloudWatch** ahora muestra automáticamente correlaciones con CloudWatch Contributor Insights
- **Nuevo endpoint X-Ray** en us-east-1 para mejor latencia en traces en tiempo real

---

## Recursos Adicionales

- [Documentación oficial AWS X-Ray](https://docs.aws.amazon.com/xray/index.html)
- [Documentación CloudWatch ServiceLens](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/ServiceLens.html)
- [AWS X-Ray SDK GitHub](https://github.com/aws/aws-xray-sdk-node)
- [X-Ray Workshop](https://catalog.workshops.aws/xray)
