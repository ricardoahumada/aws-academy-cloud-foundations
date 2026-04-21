# Lab 4.4: Mensajería Asíncrona con SQS y SNS

## Objetivo

Implementar un sistema de mensajería asíncrona usando Amazon SQS (Simple Queue Service) y Amazon SNS (Simple Notification Service) para decoupling de microservicios.

Al finalizar, comprenderás:
- Cómo SQS proporciona un sistema de colas de mensajes para desacoplar servicios
- Cómo SNS permite notificaciones pub/sub a múltiples suscriptores
- Cómo configurar dead-letter queues (DLQ) para manejo de errores
- Cómo Lambda puede procesar mensajes de una cola SQS

## Duración estimada

45 minutos

## Prerrequisitos

- Cuenta AWS con permisos para SQS, SNS, Lambda, CloudWatch
- AWS CLI configurado (`aws configure`)
- IAM role con permisos para crear recursos

## Arquitectura objetivo

```
┌─────────────────────────────────────────────────────────────────┐
│                  Arquitectura de Mensajería                     │
│                                                                 │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐  │
│  │ Producer │───▶│   SQS    │───▶│  Lambda  │───▶│   SNS    │  │
│  │ Service  │    │   FIFO   │    │ Function │    │   Topic  │  │
│  └──────────┘    │  Queue   │    └──────────┘    └────┬─────┘  │
│                  └──────────┘                           │       │
│                       ▲                                  │       │
│                       │                                  ▼       │
│                  ┌────┴────┐                    ┌──────────────┐│
│                  │   DLQ   │                    │ Subscribers  ││
│                  │ (Error)  │                    │ - Email      ││
│                  └─────────┘                    │ - HTTP/S     ││
│                                                 └──────────────┘│
└─────────────────────────────────────────────────────────────────┘
```

---

## Paso 1: Crear SQS Queue (FIFO)

### 1.1 Crear la cola principal

1. En la consola de AWS, ir a **Services** > **Amazon SQS**
2. Clic en **Create queue**

### 1.2 Configurar la cola FIFO

1. **Type**: seleccionar **FIFO**
2. **Name**: `ordenes-procesamiento.fifo`
3. **Description**: `Cola FIFO para procesamiento de órdenes`
4. Configuraciones adicionales:
   - **Content-based deduplication**: **Enable** (evita mensajes duplicados automáticamente)
   - **Encryption**: **Server-side encryption (SSE)** - recommended
5. **Dead-letter queue settings**:
   - **Send to dead-letter queue**: **Yes**
   - **Use existing queue**: **No (create new)**
   - **Dead-letter queue name**: `ordenes-dlq.fifo`
6. **Dead-letter queue parameters**:
   - **Maximum receives**: **3** (después de 3 intentos, el mensaje va a DLQ)
7. **Visibility timeout**: **30 seconds**
8. **Message retention period**: **1 day** (86400 seconds)
9. **Receive message wait time**: **0 seconds** (long polling desactivado para demo)
10. Clic en **Create Queue**

### 1.3 Crear la DLQ manualmente (alternativa)

```bash
# Crear dead-letter queue
aws sqs create-queue \
  --queue-name ordenes-dlq.fifo \
  --attributes '{
    "FifoQueue": "true",
    "ContentBasedDeduplication": "true"
  }'
```

### 1.4 Obtener URLs de las colas

```bash
# Obtener URL de la cola principal
aws sqs get-queue-url \
  --queue-name ordenes-procesamiento.fifo

# Obtener URL de la DLQ
aws sqs get-queue-url \
  --queue-name ordenes-dlq.fifo

# Listar todas las colas
aws sqs list-queues
```

---

## Paso 2: Crear SNS Topic

### 2.1 Crear el topic

1. Ir a **Services** > **Amazon SNS**
2. En el panel izquierdo, seleccionar **Topics** > **Create topic**

### 2.2 Configurar el topic

1. **Type**: **Standard** (no FIFO para SNS)
2. **Name**: `notificaciones-ordenes`
3. **Display name**: `Ordenes Notifications`
4. **Encryption**: **Enable** (recomendado)
5. **Access policy**: **Basic** (permisos por defecto)
6. Clic en **Create topic**

### 2.3 Crear suscripción Email

1. En el topic recién creado, ir a **Subscriptions** > **Create subscription**
2. Configurar:
   - **Protocol**: **Email**
   - **Endpoint**: `tu-email@example.com` (reemplazar con tu email real)
3. Clic en **Create subscription**

### 2.4 Confirmar la suscripción

1. Revisar el correo electrónico recibido (asunto: "AWS Notification - Subscription Confirmation")
2. Hacer clic en el enlace de confirmación
3. Verificar en la consola SNS que el status sea `Confirmed`

### 2.5 Crear suscripción HTTP/S (opcional)

```bash
# Crear suscripción HTTP
aws sns subscribe \
  --topic-arn arn:aws:sns:us-east-1:123456789012:notificaciones-ordenes \
  --protocol https \
  --notification-endpoint https://mi-api.example.com/webhook/sns
```

---

## Paso 3: Crear Lambda para Procesar Mensajes

### 3.1 Crear la función Lambda

1. Ir a **Services** > **AWS Lambda**
2. Clic en **Create function**

### 3.2 Configurar la función

1. **Function name**: `procesar-orden`
2. **Runtime**: **Python 3.11**
3. **Architecture**: **x86_64**
4. **Permissions**: **Create a new role with basic Lambda permissions**
5. Clic en **Create function**

### 3.3 Implementar el código

1. En el editor de código, reemplazar el código con:

```python
import json
import os

def lambda_handler(event, context):
    """
    Procesa mensajes de la cola SQS de órdenes.
    Cada mensaje contiene: order_id, customer, amount
    """
    
    # Obtener ARN del topic SNS (configurable via environment variable)
    sns_topic_arn = os.environ.get('SNS_TOPIC_ARN', '')
    
    print(f"Procesando {len(event['Records'])} mensaje(s)")
    
    for record in event['Records']:
        try:
            # El body del mensaje SQS es un string JSON
            body = json.loads(record['body'])
            
            # Extraer datos de la orden
            order_id = body.get('order_id', 'unknown')
            customer = body.get('customer', 'unknown')
            amount = body.get('amount', 0)
            
            print(f"📦 Procesando orden {order_id} para {customer}, monto: ${amount}")
            
            # Validar datos
            if not order_id or not customer:
                raise ValueError("Datos de orden incompletos")
            
            # Simular procesamiento (en producción, aquí iría la lógica de negocio)
            # Por ejemplo: actualizar base de datos, procesar pago, etc.
            
            # Log de éxito
            print(f"✅ Orden {order_id} procesada exitosamente")
            
            # En producción, aquí se podría enviar notificación SNS
            # if sns_topic_arn:
            #     send_sns_notification(sns_topic_arn, order_id, customer, amount)
            
        except json.JSONDecodeError as e:
            print(f"❌ Error parseando mensaje JSON: {e}")
            raise  # Re-lanzar para que vaya a DLQ
            
        except ValueError as e:
            print(f"❌ Error de validación: {e}")
            raise  # Re-lanzar para que vaya a DLQ
            
        except Exception as e:
            print(f"❌ Error procesando orden: {e}")
            raise  # Re-lanzar para que vaya a DLQ
    
    return {
        'statusCode': 200,
        'body': json.dumps(f'Procesadas {len(event["Records"])} orden(es)')
    }
```

2. Clic en **Deploy**

### 3.4 Configurar variable de ambiente

1. Ir a **Configuration** > **Environment variables**
2. Clic en **Edit** > **Add environment variable**:
   - **Key**: `SNS_TOPIC_ARN`
   - **Value**: `arn:aws:sns:us-east-1:123456789012:notificaciones-ordenes` (reemplazar con ARN real)

---

## Paso 4: Configurar Lambda como SQS Trigger

### 4.1 Agregar trigger SQS

1. En la función Lambda, ir a **Add trigger**
2. Seleccionar **SQS** como source
3. Configurar:
   - **SQS queue**: `ordenes-procesamiento.fifo`
   - **Batch size**: **10** (el máximo para FIFO es 10,000 desde 2022, pero 10 es un buen valor para este lab; usar 1 solo si el procesamiento debe ser estrictamente secuencial por mensaje)
   - **Batch window**: **0** (opcional, para batching)
4. Clic en **Add**

### 4.2 Verificar trigger

1. En la sección **Function overview**, verificar que aparezca el trigger SQS
2. El estado debe ser **Enabled**

---

## Paso 5: Configurar DLQ para Lambda (Manejo de Errores)

### 5.1 Crear DLQ si no existe

```bash
# Crear cola DLQ para la Lambda
aws sqs create-queue \
  --queue-name procesar-orden-dlq.fifo \
  --attributes '{
    "FifoQueue": "true",
    "ContentBasedDeduplication": "true"
  }'
```

### 5.2 Aclaración sobre DLQ en Lambda + SQS

> **Importante:** Cuando Lambda se invoca mediante un trigger SQS (event source mapping), el DLQ es gestionado por la **cola SQS** mediante la `RedrivePolicy` configurada en el Paso 1 (`ordenes-dlq.fifo`). Si Lambda lanza una excepción y agota los reintentos del event source mapping, SQS envía automáticamente el mensaje al DLQ.
>
> La configuración de DLQ en **Asynchronous invocation** de Lambda aplica únicamente a invocaciones asíncronas directas (p.ej. S3 events, EventBridge rules), NO al trigger SQS.

Para inspeccionar mensajes fallidos en el DLQ SQS:

```bash
# Ver mensajes en el DLQ
DLQ_URL=$(aws sqs get-queue-url \
  --queue-name ordenes-dlq.fifo \
  --query 'QueueUrl' --output text)

aws sqs receive-message \
  --queue-url "$DLQ_URL" \
  --max-number-of-messages 10
```

### 5.3 Verificar configuración

```bash
# Verificar configuración de la función
aws lambda get-function-configuration \
  --function-name procesar-orden \
  --query '{DeadLetterConfig:DeadLetterConfig,RuntimeConfig:RuntimeConfig}'
```

---

## Paso 6: Enviar Mensajes de Prueba

### 6.1 Enviar un solo mensaje

```bash
# Obtener queue URL
QUEUE_URL=$(aws sqs get-queue-url \
  --queue-name ordenes-procesamiento.fifo \
  --query 'QueueUrl' \
  --output text)

# Enviar mensaje de prueba
aws sqs send-message \
  --queue-url "$QUEUE_URL" \
  --message-body '{"order_id": "ORD-001", "customer": "Juan Perez", "amount": 150.00}' \
  --message-group-id orders
```

### 6.2 Enviar múltiples mensajes (simular carga)

```bash
# Enviar 5 mensajes de prueba
for i in {2..6}; do
  aws sqs send-message \
    --queue-url "$QUEUE_URL" \
    --message-body "{\"order_id\": \"ORD-00$i\", \"customer\": \"Cliente $i\", \"amount\": $((100 + RANDOM % 200)).00}" \
    --message-group-id orders
  echo "Mensaje ORD-00$i enviado"
done
```

### 6.3 Verificar mensajes enviados

```bash
# Contar mensajes en la cola
aws sqs get-queue-attributes \
  --queue-url "$QUEUE_URL" \
  --attribute-names ApproximateNumberOfMessages

# Receiving messages (para debugging, no eliminar)
aws sqs receive-message \
  --queue-url "$QUEUE_URL" \
  --max-number-of-messages 10
```

---

## Paso 7: Monitorear en CloudWatch

### 7.1 Ver logs de Lambda

1. Ir a **CloudWatch** > **Logs** > **Log groups**
2. Buscar `/aws/lambda/procesar-orden`
3. Clic en el log stream más reciente
4. Ver los mensajes de procesamiento:

```
START RequestId: xxx-xxx-xxx Version: $LATEST
2026-03-31T10:00:00.000Z	📦 Procesando orden ORD-001 para Juan Perez, monto: $150.00
2026-03-31T10:00:00.050Z	✅ Orden ORD-001 procesada exitosamente
END RequestId: xxx-xxx-xxx
```

### 7.2 Ver métricas de SQS

1. Ir a **SQS** > **Colas** > `ordenes-procesamiento.fifo`
2. Ir a la pestaña **Monitoring**
3. Ver métricas:
   - **Number of messages sent**: Mensajes enviados
   - **Number of messages received**: Mensajes recibidos por consumers
   - **Number of messages deleted**: Mensajes procesados exitosamente
   - **Approximate age of oldest message**: Tiempo en cola

### 7.3 Ver métricas de Lambda

```bash
# Invocar función manualmente para generar métricas
# IMPORTANTE: el payload debe tener el formato SQS event con 'Records'
# Un payload sin 'Records' causa KeyError en la función
aws lambda invoke \
  --function-name procesar-orden \
  --payload '{"Records":[{"body":"{\\"order_id\\":\\"TEST-001\\",\\"customer\\":\\"Test User\\",\\"amount\\":99.99}"}]}' \
  response.json

# Ver métricas en CloudWatch
aws cloudwatch get-metric-statistics \
  --namespace AWS/Lambda \
  --metric-name Invocations \
  --dimensions Name=FunctionName,Value=procesar-orden \
  --start-time $(date -u -d "12 hours ago" +"%Y-%m-%dT%H:%M:%SZ") \
  --end-time $(date -u +"%Y-%m-%dT%H:%M:%SZ") \
  --period 3600 \
  --statistics Sum

aws cloudwatch get-metric-statistics \
  --namespace AWS/Lambda \
  --metric-name Errors \
  --dimensions Name=FunctionName,Value=procesar-orden \
  --start-time $(date -u -d "12 hours ago" +"%Y-%m-%dT%H:%M:%SZ") \
  --end-time $(date -u +"%Y-%m-%dT%H:%M:%SZ") \
  --period 3600 \
  --statistics Sum
```

---

## Verificación Final

Al completar este lab, debes ser capaz de:

- [ ] Crear una cola SQS FIFO con deduplicación content-based
- [ ] Crear un topic SNS con suscripción Email
- [ ] Crear una función Lambda con trigger SQS
- [ ] Configurar dead-letter queues para manejo de errores
- [ ] Enviar mensajes a la cola SQS
- [ ] Verificar procesamiento de mensajes en CloudWatch Logs
- [ ] Explicar el patrón de decoupling entre productores y consumidores

---

## Errores Comunes y Soluciones

| Error | Causa | Solución |
|-------|-------|----------|
| `MessageGroupId is required` | FIFO queue requiere message group ID | Usar `--message-group-id orders` en el comando |
| `DuplicateMessage` | Mensaje duplicado enviado | Habilitar `ContentBasedDeduplication` en la cola |
| `Lambda not triggered` | Trigger no configurado correctamente | Verificar que el trigger SQS esté habilitado |
| `DLQ not delivering` | Máximo de receives excedido | Verificar configuración de DLQ en la cola |
| `MaximumPolingIntervalExceeded` | Lambda tarda demasiado | Reducir visibility timeout o aumentar timeout de Lambda |
| Email no recibido | Suscripción no confirmada | Confirmar desde el email o verificar subscription status |

---

## Limpieza de Recursos

Para evitar costos innecesarios, al finalizar el lab ejecutar:

```bash
# Eliminar el event source mapping (trigger SQS) de Lambda
# Primero obtener el UUID del mapping
ESM_UUID=$(aws lambda list-event-source-mappings \
  --function-name procesar-orden \
  --query 'EventSourceMappings[0].UUID' \
  --output text)
aws lambda delete-event-source-mapping --uuid "$ESM_UUID"

# Eliminar función Lambda
aws lambda delete-function \
  --function-name procesar-orden

# Eliminar suscripciones SNS
aws sns list-subscriptions-by-topic \
  --topic-arn arn:aws:sns:us-east-1:123456789012:notificaciones-ordenes \
  --query 'Subscriptions[*].SubscriptionArn' \
  --output text | grep -v "^None" | \
  while read arn; do
    aws sns unsubscribe --subscription-arn "$arn"
  done

# Eliminar topic SNS
aws sns delete-topic \
  --topic-arn arn:aws:sns:us-east-1:123456789012:notificaciones-ordenes

# Eliminar colas SQS
aws sqs delete-queue --queue-url https://sqs.us-east-1.amazonaws.com/123456789012/ordenes-procesamiento.fifo
aws sqs delete-queue --queue-url https://sqs.us-east-1.amazonaws.com/123456789012/ordenes-dlq.fifo
aws sqs delete-queue --queue-url https://sqs.us-east-1.amazonaws.com/123456789012/procesar-orden-dlq.fifo
```

---

## Patrones de Diseño con SQS y SNS

### Patrón 1: Cola de Tareas (Task Queue)
```
Producer → SQS Queue → Lambda/Worker → Database
```
- Uso: Procesamiento asíncrono de tareas
- Ejemplo: Generar reportes, procesar imágenes

### Patrón 2: Fan-out (Pub/Sub)
```
Producer → SNS Topic → Subscriber 1
                    → Subscriber 2
                    → Subscriber N
```
- Uso: Notificar a múltiples sistemas
- Ejemplo: Enviar notificaciones a email, SMS, push

### Patrón 3: Event-Driven con DLQ
```
Producer → SQS → Lambda (fallback: DLQ)
```
- Uso: Garantizar procesamiento con reintentos
- Ejemplo: Órdenes de compra, transacciones

### Comparación SQS vs SNS

| Característica | SQS | SNS |
|---------------|-----|-----|
| **Pattern** | Point-to-point (cola) | Pub/Sub (tema) |
| **Consumers** | Un consumer por mensaje | Múltiples suscriptores |
| **Delivery** | Polling (consumer pide) | Push (SNS envía) |
| **Order** | FIFO disponible | Order no garantizada |
| **Use case** | Task queues, job processing | Notifications, fan-out |
| **Precio** | Por mensaje | Por mensaje + notificaciones |
