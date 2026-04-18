#!/bin/bash
# ============================================
# Script para crear SQS + DLQ - Lab 6.2
# Event-Driven Architecture con EventBridge
# ============================================

set -e

# Configuración
STACK_NAME="lab62-infrastructure"
REGION="us-east-1"

echo "=== Creando Infraestructura para Lab 6.2 ==="

# ============================================
# 1. Crear Dead Letter Queue
# ============================================
echo "1. Creando Dead Letter Queue..."

DLQ_RESPONSE=$(aws sqs create-queue \
    --queue-name "lab62-dlq.fifo" \
    --attributes \
        '{\"FifoQueue\":\"true\",\"VisibilityTimeout\":\"60\",\"MessageRetentionPeriod\":\"1209600\"}' \
    --region ${REGION} \
    --output json)

DLQ_URL=$(echo ${DLQ_RESPONSE} | jq -r '.QueueUrl')
DLQ_ARN=$(aws sqs get-queue-attributes \
    --queue-url ${DLQ_URL} \
    --attribute-names QueueArn \
    --region ${REGION} \
    --query 'Attributes.QueueArn' \
    --output text)

echo "DLQ URL: ${DLQ_URL}"
echo "DLQ ARN: ${DLQ_ARN}"

# ============================================
# 2. Crear Cola de Procesamiento Principal
# ============================================
echo "2. Creando Cola Principal..."

REDRIVE_POLICY="{\"deadLetterTargetArn\":\"${DLQ_ARN}\",\"maxReceiveCount\":5}"

MAIN_QUEUE_RESPONSE=$(aws sqs create-queue \
    --queue-name "lab62-processing-queue.fifo" \
    --attributes \
        "{\"FifoQueue\":\"true\",\"VisibilityTimeout\":\"60\",\"ReceiveMessageWaitTimeSeconds\":\"20\",\"RedrivePolicy\":\"${REDRIVE_POLICY}\"}" \
    --region ${REGION} \
    --output json)

MAIN_QUEUE_URL=$(echo ${MAIN_QUEUE_RESPONSE} | jq -r '.QueueUrl')
MAIN_QUEUE_ARN=$(aws sqs get-queue-attributes \
    --queue-url ${MAIN_QUEUE_URL} \
    --attribute-names QueueArn \
    --region ${REGION} \
    --query 'Attributes.QueueArn' \
    --output text)

echo "Main Queue URL: ${MAIN_QUEUE_URL}"
echo "Main Queue ARN: ${MAIN_QUEUE_ARN}"

# ============================================
# 3. Crear EventBridge Event Bus
# ============================================
echo "3. Creando EventBridge Event Bus..."

EVENT_BUS_NAME="lab62-event-bus"

aws events create-event-bus \
    --name ${EVENT_BUS_NAME} \
    --region ${REGION} 2>/dev/null || echo "Event bus ya existe o no se pudo crear"

# Crear regla para rutear eventos a SQS
echo "4. Creando Regla EventBridge..."

EVENT_PATTERN='{"source":["aws.lambda", "aws.ec2"]}'

aws events put-rule \
    --name "lab62-sqs-rule" \
    --event-pattern "${EVENT_PATTERN}" \
    --state ENABLED \
    --region ${REGION} \
    --output text > /dev/null

# Agregar target SQS a la regla
aws events put-targets \
    --rule "lab62-sqs-rule" \
    --targets "{\"Id\":\"lab62-target\",\"Arn\":\"${MAIN_QUEUE_ARN}\"}" \
    --region ${REGION} \
    --output text > /dev/null

# ============================================
# 5. Crear Topic SNS para Notificaciones
# ============================================
echo "5. Creando Topic SNS..."

SNS_TOPIC_ARN=$(aws sns create-topic \
    --name "lab62-notifications" \
    --region ${REGION} \
    --query 'TopicArn' \
    --output text)

echo "SNS Topic ARN: ${SNS_TOPIC_ARN}"

# Suscribir cola al SNS
aws sns subscribe \
    --topic-arn ${SNS_TOPIC_ARN} \
    --protocol sqs \
    --notification-endpoint ${MAIN_QUEUE_ARN} \
    --region ${REGION} \
    --output text > /dev/null

# ============================================
# Resumen
# ============================================
echo ""
echo "=== Recursos Creados ==="
echo "DLQ URL: ${DLQ_URL}"
echo "Main Queue URL: ${MAIN_QUEUE_URL}"
echo "Event Bus: ${EVENT_BUS_NAME}"
echo "SNS Topic: ${SNS_TOPIC_ARN}"
echo ""
echo "Guardar estos valores para configurar Lambda:"
