# Lab 6.2: Pipeline de Procesamiento de Eventos con EventBridge

## Objetivo

Implementar un pipeline de procesamiento de eventos utilizando EventBridge como bus de eventos, Lambda como procesador, y SQS como cola de mensajes fallidos (Dead Letter Queue). Aprenderás a crear event buses personalizados, definir reglas de matching de eventos y configurar targets.

## Duración estimada

45 minutos

## Prerrequisitos

- Cuenta AWS activa con acceso a EventBridge, Lambda, SQS y CloudWatch
- AWS CLI configurado con credenciales válidas
- Conocimientos básicos de Python y arquitecturas event-driven
- Permisos IAM suficientes para crear todos los recursos

## Arquitectura del Lab

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  aws events     │────►│  EventBridge    │────►│  Lambda         │
│  put-events     │     │  Event Bus      │     │  process-order  │
└─────────────────┘     │                 │     │                 │
                       │  order-event-bus │     └─────────────────┘
                       └─────────────────┘             │
                                                      │ (on failure)
                                                      ▼
                                            ┌─────────────────┐
                                            │  SQS FIFO       │
                                            │  DLQ            │
                                            └─────────────────┘
```

## Recursos creados

| Recurso | Nombre | Tipo |
|---------|--------|------|
| SQS Queue (principal) | `order-processing-queue.fifo` | Amazon SQS |
| SQS Queue (DLQ) | `order-processing-dlq` | Amazon SQS (Standard) |
| Función Lambda | `process-order` | AWS Lambda |
| Event Bridge | `order-event-bus` | Amazon EventBridge |
| EventBridge Rule | `order-created-rule` | Amazon EventBridge |

---

## Pasos

### Paso 1: Crear la Dead Letter Queue (DLQ)

1.1. Abre la consola de AWS en https://console.aws.amazon.com

1.2. Navega a **SQS** > **Queues** > **Create queue**

1.3. En la configuración de la cola:
   - **Type**: **Standard** (NO FIFO)
   - **Name**: `order-processing-dlq`
   - **Description** (opcional): Cola para mensajes fallidos

   > **IMPORTANTE**: EventBridge solo puede enviar eventos fallidos a colas SQS **Standard**. Las colas FIFO requieren un `MessageGroupId` que EventBridge no proporciona al hacer entregas a DLQ, por lo que la entrega fallaría.

1.4. En **Configuration**:
   - **Visibility timeout**: 30 seconds (valor por defecto)
   - **Message retention period**: 4 days (valor por defecto)
   - **Maximum message size**: 256 KB (valor por defecto)

1.5. Haz clic en **Create queue**

1.6. En la página de la cola, copia el **URL** y el **ARN** para usarlos más adelante

---

### Paso 2: Crear la Cola de Procesamiento Principal

2.1. Navega a **SQS** > **Queues** > **Create queue**

2.2. Configura:
   - **Type**: FIFO
   - **Name**: `order-processing-queue.fifo`
   - **Description** (opcional): Cola principal para procesamiento de órdenes

2.3. En **Configuration**:
   - **Visibility timeout**: 30 seconds
   - **Receive message wait time**: 0 seconds
   - **Message retention period**: 4 days

2.4. En **Dead letter queue**:
   - **Dead letter queue**: Yes
   - **Dead letter queue ARN**: Pega el ARN de la DLQ (`order-processing-dlq`) creada en el Paso 1
   - **Maximum receives**: 3 (el mensaje irá a DLQ después de 3 intentos fallidos)

2.5. Haz clic en **Create queue**

2.6. Copia el **ARN** de esta cola para el Paso 4

---

### Paso 3: Crear la Función Lambda

3.1. Navega a **Lambda** > **Functions** > **Create function**

3.2. Configura:
   - **Function name**: `process-order`
   - **Runtime**: Python 3.11
   - **Architecture**: x86_64
   - **Permissions**: Create a new role with basic Lambda permissions

3.3. Haz clic en **Create function**

3.4. En el editor de código, reemplaza el código existente con:

```python
import json
import random

def lambda_handler(event, context):
    # Print event for debugging
    print(f"Received event: {json.dumps(event)}")
    
    # EventBridge places the event Detail object directly under event['detail']
    # Each put-events entry generates one Lambda invocation with one order
    detail = event.get('detail', {})
    
    if not detail:
        print("No detail found in event")
        return {
            'statusCode': 200,
            'body': json.dumps('No detail to process')
        }
    
    try:
        order_id = detail.get('orderId', 'UNKNOWN')
        customer_id = detail.get('customerId', 'UNKNOWN')
        amount = detail.get('amount', 0)
        
        print(f"Processing order {order_id} for customer {customer_id}, amount: ${amount}")
        
        # Simulate processing with 10% chance of failure
        if random.random() < 0.1:
            print(f"Simulated failure for order {order_id}")
            raise Exception(f"Simulated failure for order {order_id}")
        
        print(f"Successfully processed order {order_id}")
        
        return {
            'statusCode': 200,
            'body': json.dumps(f'Processed order {order_id} successfully')
        }
        
    except Exception as e:
        print(f"Error processing order: {str(e)}")
        # EventBridge reintentará según la Retry policy; tras agotar reintentos,
        # el evento va a la DLQ configurada en la regla.
        raise
```

3.5. En la sección **Basic settings**:
   - **Timeout**: 30 seconds (para este lab)

3.6. Haz clic en **Deploy**

---

### Paso 4: Crear el Event Bus Personalizado

4.1. Navega a **EventBridge** > **Event buses** > **Create event bus**

4.2. Configura:
   - **Name**: `order-event-bus`
   - **Description** (opcional): Event bus para eventos de órdenes

4.3. Haz clic en **Create**

4.4. En la página del event bus, copia el **ARN** para usarla en la regla

---

### Paso 5: Crear la Regla de EventBridge

5.1. Navega a **EventBridge** > **Rules** > **Create rule**

5.2. En el asistente de creación:

   **Step 1: Define rule detail**:
   - **Name**: `order-created-rule`
   - **Description** (opcional): Regla para procesar órdenes creadas
   - **Event bus**: `order-event-bus`
   - **Rule type**: Rule with pattern

   - Haz clic en **Next**

   **Step 2: Build event pattern**:
   - Selecciona **Custom pattern**
   - En el editor de JSON, pega:

```json
{
  "source": ["com.mycompany.orders"],
  "detail-type": ["OrderCreated"],
  "detail": {
    "status": ["pending"]
  }
}
```

   - Haz clic en **Next**

   **Step 3: Select targets**:
   - **Target type**: AWS service
   - **Select a target**: Lambda function
   - **Function**: `process-order`

   - En **Additional settings**:
     - **Retry attempts**: 2
     - **Dead-letter queue**: SQS queue
     - **Queue ARN**: Pega el ARN de la cola `order-processing-dlq` (la DLQ Standard del Paso 1)

   > **NOTA**: El DLQ configurado aquí es el de **EventBridge**: recibe los eventos que EventBridge no pudo entregar a Lambda tras agotar los reintentos. Es diferente del DLQ que configuraste en la cola SQS principal (Paso 2).

   - Haz clic en **Next**

   **Step 4: Review and create**:
   - Revisa la configuración
   - Haz clic en **Create rule**

---

### Paso 6: Agregar Permisos para PutEvents

6.1. La función Lambda necesita permisos para ser invocada por EventBridge

6.2. Navega a **Lambda** > **Functions** > `process-order`

6.3. En la pestaña **Configuration** > **Permissions**

6.4. En **Resource-based policy**, haz clic en **Add permissions**

6.5. Selecciona **AWS service** y configura:
   - **Service**: EventBridge
   - **Principal**: events.amazonaws.com
   - **Source account**: Tu Account ID
   - **Statement ID**: allow-eventbridge-invoke

6.6. Alternativamente, puedes ejecutar este comando AWS CLI:

```bash
# Obtener el Account ID dinámicamente
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

aws lambda add-permission \
    --function-name process-order \
    --statement-id allow-eventbridge-invoke \
    --action "lambda:InvokeFunction" \
    --principal events.amazonaws.com \
    --source-account $ACCOUNT_ID
```

---

### Paso 7: Simular Eventos con AWS CLI

7.1. Abre una terminal o command prompt

7.2. Ejecuta el siguiente comando para enviar un evento de prueba:

```bash
# Enviar evento de prueba
aws events put-events \
    --entries '[{
        "EventBusName": "order-event-bus",
        "Source": "com.mycompany.orders",
        "DetailType": "OrderCreated",
        "Detail": "{\"orderId\": \"ORD-001\", \"customerId\": \"CUST-001\", \"amount\": 100.00, \"status\": \"pending\"}"
    }]'
```

7.3. Verifica que la respuesta indique éxito:
```json
{
    "FailedEntryCount": 0,
    "Entries": [
        {
            "EventId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
            "ErrorCode": null,
            "ErrorMessage": null
        }
    ]
}
```

7.4. Envía algunos eventos más para probar:

```bash
aws events put-events \
    --entries '[{
        "EventBusName": "order-event-bus",
        "Source": "com.mycompany.orders",
        "DetailType": "OrderCreated",
        "Detail": "{\"orderId\": \"ORD-002\", \"customerId\": \"CUST-002\", \"amount\": 250.00, \"status\": \"pending\"}"
    },
    {
        "EventBusName": "order-event-bus",
        "Source": "com.mycompany.orders",
        "DetailType": "OrderCreated",
        "Detail": "{\"orderId\": \"ORD-003\", \"customerId\": \"CUST-003\", \"amount\": 75.50, \"status\": \"pending\"}"
    }]'
```

---

### Paso 8: Verificar el Procesamiento en CloudWatch

8.1. Navega a **CloudWatch** > **Logs** > **Log groups**

8.2. Busca el log group `/aws/lambda/process-order`

8.3. Haz clic en el log stream más reciente

8.4. Revisa los logs de ejecución. Deberías ver entradas como:

```
START RequestId: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx Version: $LATEST
Received event: {...}
Processing order ORD-001 for customer CUST-001, amount: $100.0
Successfully processed order ORD-001
END RequestId: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

8.5. Si algún evento falló (10% de probabilidad), verás:

```
Processing order ORD-xxx for customer CUST-xxx, amount: $xxx
Simulated failure for order ORD-xxx
Error processing orders: Simulated failure for order ORD-xxx
```

8.6. Si EventBridge agota los reintentos (Retry attempts: 2 = 3 intentos totales) y no puede entregar el evento a Lambda, verifica que los eventos fallidos lleguen a la DLQ de EventBridge:

   - Navega a **SQS** > **Queues** > `order-processing-dlq`
   - Haz clic en **Send and receive messages**
   - Haz clic en **Poll for messages**
   - Verifica que aparecen mensajes de las órdenes que EventBridge no pudo entregar

---

## Verificación

Al finalizar el lab, verifica que puedes realizar las siguientes acciones:

- [ ] La cola `order-processing-queue.fifo` está creada con Redrive policy configurada
- [ ] La cola `order-processing-dlq` (Standard) está creada
- [ ] La función Lambda `process-order` está creada y desplegada
- [ ] El event bus `order-event-bus` está creado
- [ ] La regla `order-created-rule` está creada y habilitada
- [ ] El comando `aws events put-events` envía eventos sin errores
- [ ] Los logs de CloudWatch muestran las invocaciones de Lambda
- [ ] Los mensajes fallidos aparecen en la DLQ después de 3 intentos

---

## Errores Comunes y Soluciones

| Error | Causa probable | Solución |
|-------|---------------|----------|
| `EventBridge cannot deliver to target` | Permisos insuficientes | Verificar que Lambda tiene permisos de ejecución y que el policy de recursos permite invocar desde EventBridge |
| `The JSON provided does not match` | Event pattern incorrecto | Verificar la sintaxis JSON del event pattern |
| Mensajes no llegan a DLQ | DLQ no configurada correctamente | Verificar que el ARN de la DLQ está correcto y que la cola existe |
| Lambda no se invoca | Regla no está habilitada | Verificar que la regla está en estado "Enabled" |
| `No records found in event` | Formato de evento incorrecto | Verificar que el evento tiene la estructura correcta con `detail.records` |
| La cola FIFO no recibe mensajes | Nombre sin sufijo `.fifo` | Las colas FIFO deben terminar con `.fifo` |

---

## Limpieza de Recursos

Para eliminar los recursos creados y evitar costos adicionales:

1. **Eliminar la regla de EventBridge**:
   - EventBridge > Rules > `order-created-rule` > Delete

2. **Eliminar el event bus**:
   - EventBridge > Event buses > `order-event-bus` > Delete

3. **Eliminar la función Lambda**:
   - Lambda > Functions > `process-order` > Delete

4. **Eliminar las colas SQS**:
   - SQS > Queues > Seleccionar `order-processing-queue.fifo` y `order-processing-dlq` > Delete

---

## Conceptos Clave Explicados

### EventBridge Event Bus
Un event bus es un conducto que recibe eventos. Puedes tener event buses:
- **Default**: Recibe eventos de servicios AWS
- **Custom**: Creado por ti para tus aplicaciones
- **Partner**: Para recibir eventos de aplicaciones SaaS partners

### Event Patterns
Los event patterns definen qué eventos deben coincidir para activar una regla. En el lab, el patrón:
```json
{
  "source": ["com.mycompany.orders"],
  "detail-type": ["OrderCreated"],
  "detail": {"status": ["pending"]}
}
```
Significa que solo los eventos de tipo "OrderCreated" con status "pending" serán procesados.

### Dead Letter Queue (DLQ)
La DLQ recibe mensajes que no pudieron ser procesados después de varios intentos. Esto permite:
- No perder mensajes importantes
- Analizar mensajes fallidos posteriormente
- Evitar que mensajes problemáticos bloqueen el procesamiento

### Retry Behavior
EventBridge reintenta automáticamente las invocaciones a Lambda si fallan:
- Reintentos con exponential backoff
- Hasta 24 horas de retención de eventos fallidos
- DLQ para mensajes que fallan todos los reintentos
