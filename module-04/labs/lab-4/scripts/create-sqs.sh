#!/bin/bash
# ============================================
# Script para crear SQS Queue - Lab 4.4
# Sistema de Mensajería Asíncrona
# ============================================

set -e

# Configuración
QUEUE_NAME="mi-cola-fifo"
DLQ_NAME="mi-dlq"
REGION="us-east-1"

echo "=== Creando SQS Queues para Lab 4.4 ==="

# ============================================
# Crear Dead Letter Queue (DLQ)
# ============================================
echo "1. Creando Dead Letter Queue..."

DLQ_URL=$(aws sqs create-queue \
    --queue-name "${DLQ_NAME}.fifo" \
    --attributes \
        "FifoQueue=true" \
        "VisibilityTimeout=30" \
        "ReceiveMessageWaitTimeSeconds=20" \
        "MessageRetentionPeriod=1209600" \
    --region ${REGION} \
    --query 'QueueUrl' \
    --output text)

echo "DLQ creada: ${DLQ_URL}"

# Obtener ARN del DLQ
DLQ_ARN=$(aws sqs get-queue-attributes \
    --queue-url ${DLQ_URL} \
    --attribute-names QueueArn \
    --region ${REGION} \
    --query 'Attributes.QueueArn' \
    --output text)

echo "DLQ ARN: ${DLQ_ARN}"

# ============================================
# Crear Cola Principal (con DLQ)
# ============================================
echo "2. Creando Cola Principal con DLQ..."

# Obtener ARN del DLQ para configurar redrive policy
REDIRIVE_POLICY="{\"deadLetterTargetArn\":\"${DLQ_ARN}\",\"maxReceiveCount\":3}"

QUEUE_URL=$(aws sqs create-queue \
    --queue-name "${QUEUE_NAME}.fifo" \
    --attributes \
        "FifoQueue=true" \
        "VisibilityTimeout=30" \
        "ReceiveMessageWaitTimeSeconds=20" \
        "MessageRetentionPeriod=345600" \
        "RedrivePolicy=${REDIRIVE_POLICY}" \
    --region ${REGION} \
    --query 'QueueUrl' \
    --output text)

echo "Cola principal creada: ${QUEUE_URL}"

# Obtener ARN de la cola principal
QUEUE_ARN=$(aws sqs get-queue-attributes \
    --queue-url ${QUEUE_URL} \
    --attribute-names QueueArn \
    --region ${REGION} \
    --query 'Attributes.QueueArn' \
    --output text)

echo "Cola ARN: ${QUEUE_ARN}"

# ============================================
# Crear Topic SNS para Pub/Sub
# ============================================
echo "3. Creando Topic SNS..."

SNS_TOPIC=$(aws sns create-topic \
    --name "mi-topic-notificaciones" \
    --region ${REGION} \
    --query 'TopicArn' \
    --output text)

echo "SNS Topic creado: ${SNS_TOPIC}"

# Suscribir la cola SQS al topic SNS
echo "4. Suscribiendo cola SQS al Topic SNS..."

aws sns subscribe \
    --topic-arn ${SNS_TOPIC} \
    --protocol sqs \
    --notification-endpoint ${QUEUE_ARN} \
    --region ${REGION} \
    --output text > /dev/null

echo "Suscripción creada exitosamente"

# ============================================
# Resumen
# ============================================
echo ""
echo "=== Resumen de Recursos Creados ==="
echo "DLQ URL: ${DLQ_URL}"
echo "DLQ ARN: ${DLQ_ARN}"
echo "Cola Principal URL: ${QUEUE_URL}"
echo "Cola Principal ARN: ${QUEUE_ARN}"
echo "SNS Topic ARN: ${SNS_TOPIC}"
echo ""
echo "Para probar la cola:"
echo "  aws sqs send-message --queue-url ${QUEUE_URL} --message-body 'Test message' --message-group-id 'test' --region ${REGION}"
