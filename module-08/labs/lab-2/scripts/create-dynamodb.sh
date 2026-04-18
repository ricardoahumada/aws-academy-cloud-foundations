#!/bin/bash
# ============================================
# Script para crear DynamoDB con VPC Endpoint
# Lab 8.2 - VPC Endpoints (PrivateLink)
# ============================================

set -e

REGION="us-east-1"
TABLE_NAME="Users"
ENDPOINT_NAME="dynamodb-endpoint"

echo "=== Creando DynamoDB con VPC Endpoint ==="

# ============================================
# 1. Crear tabla DynamoDB
# ============================================
echo "1. Creando tabla DynamoDB: ${TABLE_NAME}..."

# Verificar si la tabla ya existe
if aws dynamodb describe-table --table-name ${TABLE_NAME} --region ${REGION} &>/dev/null; then
    echo "Tabla ${TABLE_NAME} ya existe"
    TABLE_ARN=$(aws dynamodb describe-table \
        --table-name ${TABLE_NAME} \
        --region ${REGION} \
        --query 'Table.TableArn' \
        --output text)
else
    # Crear tabla con GSI paraemail
    aws dynamodb create-table \
        --table-name ${TABLE_NAME} \
        --attribute-definitions \
            AttributeName=UserId,AttributeType=S \
            AttributeName=Email,AttributeType=S \
        --key-schema \
            AttributeName=UserId,KeyType=HASH \
        --global-secondary-indexes \
            "[{\"IndexName\":\"EmailIndex\",\"KeySchema\":[{\"AttributeName\":\"Email\",\"KeyType\":\"HASH\"}],\"Projection\":{\"ProjectionType\":\"ALL\"},\"ProvisionedThroughput\":{\"ReadCapacityUnits\":5,\"WriteCapacityUnits\":5}}]" \
        --provisioned-throughput \
            ReadCapacityUnits=10,WriteCapacityUnits=10 \
        --region ${REGION} \
        --output json > /dev/null
    
    TABLE_ARN=$(aws dynamodb describe-table \
        --table-name ${TABLE_NAME} \
        --region ${REGION} \
        --query 'Table.TableArn' \
        --output text)
    
    echo "Tabla creada: ${TABLE_ARN}"
fi

# ============================================
# 2. Habilitar PITR (Point-in-time recovery)
# ============================================
echo "2. Habilitando Point-in-time Recovery..."

aws dynamodb update-continuous-backups \
    --table-name ${TABLE_NAME} \
    --point-in-time-recovery-specification PointInTimeRecoveryEnabled=true \
    --region ${REGION} \
    --output text > /dev/null

echo "PITR habilitado"

# ============================================
# 3. Insertar datos de prueba
# ============================================
echo "3. Insertando datos de prueba..."

aws dynamodb put-item \
    --table-name ${TABLE_NAME} \
    --item '{"UserId": {"S": "1"}, "Name": {"S": "Juan Pérez"}, "Email": {"S": "juan@example.com"}, "Status": {"S": "active"}}' \
    --region ${REGION} \
    --output text > /dev/null

aws dynamodb put-item \
    --table-name ${TABLE_NAME} \
    --item '{"UserId": {"S": "2"}, "Name": {"S": "María García"}, "Email": {"S": "maria@example.com"}, "Status": {"S": "active"}}' \
    --region ${REGION} \
    --output text > /dev/null

aws dynamodb put-item \
    --table-name ${TABLE_NAME} \
    --item '{"UserId": {"S": "3"}, "Name": {"S": "Carlos López"}, "Email": {"S": "carlos@example.com"}, "Status": {"S": "inactive"}}' \
    --region ${REGION} \
    --output text > /dev/null

echo "Datos insertados"

# ============================================
# 4. Crear VPC Endpoint para DynamoDB
# ============================================
echo "4. Creando VPC Endpoint (Gateway) para DynamoDB..."

VPC_ID=$(aws ec2 describe-vpcs \
    --filters "Name=tag:Name,Values=mi-vpc" \
    --region ${REGION} \
    --query 'Vpcs[0].VpcId' \
    --output text)

if [ -z "${VPC_ID}" ]; then
    echo "ERROR: No se encontró VPC con tag Name=mi-vpc"
    exit 1
fi

echo "VPC ID: ${VPC_ID}"

# Obtener route tables de la VPC
ROUTE_TABLE_IDS=$(aws ec2 describe-route-tables \
    --filters "Name=vpc-id,Values=${VPC_ID}" \
    --region ${REGION} \
    --query 'RouteTables[*].RouteTableId' \
    --output text)

# Crear VPC Endpoint (Gateway) para DynamoDB
ENDPOINT_ID=$(aws ec2 create-vpc-endpoint \
    --vpc-id ${VPC_ID} \
    --service-name "com.amazonaws.${REGION}.dynamodb" \
    --route-table-ids ${ROUTE_TABLE_IDS} \
    --vpc-endpoint-type Gateway \
    --region ${REGION} \
    --query 'VpcEndpoint.VpcEndpointId' \
    --output text 2>/dev/null || echo "Endpoint ya existe")

echo "VPC Endpoint ID: ${ENDPOINT_ID}"

# ============================================
# Resumen
# ============================================
echo ""
echo "=== Resumen ==="
echo "DynamoDB Table: ${TABLE_NAME}"
echo "Table ARN: ${TABLE_ARN}"
echo "VPC ID: ${VPC_ID}"
echo "VPC Endpoint: ${ENDPOINT_ID}"
echo ""
echo "El acceso a DynamoDB ahora está disponible"
echo "desde instancias en la VPC sin NAT ni Internet Gateway"
