# Pre-Labs Configuration: Habilitar CloudWatch Logs

**Duración:** 45 minutos  
**Nivel:** Intermedio  
**Servicios:** CloudWatch, EC2, Lambda, ALB, RDS, CloudWatch Agent

---

## Objetivo

Este documento describe cómo habilitar CloudWatch Logs para los servicios utilizados en los Labs del Módulo 4b (EC2, Lambda, ALB, RDS) antes de ejecutar los labs de monitoreo.

---

## 1. CloudWatch Agent en EC2

### Instalar el Agent (SSM Run Command)

1. Ir a **AWS Systems Manager** > **Run Command**
2. Buscar: **AWS-ConfigureAWSPackage**
3. Configuration:
   - **Name**: `AmazonCloudWatchAgent`
   - **Action**: Install
   - **Version**: latest
4. **Targets**: Seleccionar instancias EC2 por tags o manualmente
5. Clic en **Run**

### Configurar el Agent (archivo config.json)

En cada instancia EC2, crear `/opt/aws/amazon-cloudwatch-agent/bin/config.json`:

```json
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/httpd/access_log",
            "log_group_name": "/aws/ec2/application-logs",
            "log_stream_name": "{instance_id}/apache-access"
          },
          {
            "file_path": "/var/log/httpd/error_log",
            "log_group_name": "/aws/ec2/application-logs",
            "log_stream_name": "{instance_id}/apache-error"
          },
          {
            "file_path": "/var/log/nginx/access.log",
            "log_group_name": "/aws/ec2/application-logs",
            "log_stream_name": "{instance_id}/nginx-access"
          }
        ]
      }
    }
  },
  "metrics": {
    "metrics_collected": {
      "cpu": {},
      "mem": {
        "measurement": ["used", "cached"]
      },
      "disk": {
        "measurement": ["used", "free"]
      }
    }
  }
}
```

### Iniciar el agente

```bash
# Verificar estado
sudo systemctl status amazon-cloudwatch-agent

# Iniciar
sudo systemctl start amazon-cloudwatch-agent
sudo systemctl enable amazon-cloudwatch-agent
```

### Verificar desde CLI

```bash
aws logs describe-log-groups --log-group-name-prefix /aws/ec2/
```

---

## 2. Lambda (automático)

Lambda envía logs automáticamente a CloudWatch. No requiere instalación adicional.

### Verificación

1. Ir a **Lambda** > **Functions**
2. Seleccionar función
3. Ir a **Monitor** > **View logs in CloudWatch**

### Log Groups creados automáticamente

- `/aws/lambda/<function-name>`

### Para mejor logging en código

```python
import logging
import json
import time

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    # Log con contexto
    logger.info("Lambda execution started")
    logger.info(f"Request ID: {context.aws_request_id}")
    logger.info(f"Event: {json.dumps(event)}")
    
    start_time = time.time()
    
    try:
        # Tu código aquí
        result = process_event(event)
        
        logger.info(f"Execution time: {time.time() - start_time:.3f}s")
        logger.info(f"Result: {json.dumps(result)}")
        
        return {
            'statusCode': 200,
            'body': json.dumps(result)
        }
    except Exception as e:
        logger.error(f"Error: {str(e)}")
        raise
```

---

## 3. ALB (Access Logs hacia S3)

### Paso 1: Crear Bucket S3

1. Ir a **S3** > **Create bucket**
2. Nombre: `mi-alb-logs-<region>-<account-id>`
3. Region: Misma que el ALB
4. Bloquear acceso público
5. Crear

### Paso 2: Configurar política del bucket

En el bucket > **Permissions** > **Bucket policy**:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::127311923021:root"
            },
            "Action": "s3:PutObject",
            "Resource": "arn:aws:s3:::mi-alb-logs-*/AWSLogs/*"
        },
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "delivery.logs.amazonaws.com"
            },
            "Action": "s3:PutObject",
            "Resource": "arn:aws:s3:::mi-alb-logs-*/AWSLogs/*"
        }
    ]
}
```

### Paso 3: Habilitar Access Logs en ALB

1. Ir a **EC2** > **Load Balancers**
2. Seleccionar ALB
3. **Actions** > **Edit attributes**
4. En **Access logs**:
   - ✅ Enable access logs
   - S3 location: `s3://mi-alb-logs-<region>-<account-id>/logs`
5. Guardar

### Para usar en CloudWatch Logs Insights

Los logs del ALB van a S3, no directamente a CloudWatch. Opciones:

| Opción | Descripción | Uso en Labs |
|--------|-------------|-------------|
| **Opción A** | Usar logs de aplicación desde servidor web en EC2 (recomendado) | Lab 4b.2 |
| **Opción B** | Lambda que lee de S3 y envía a CloudWatch | Avanzado |

Para los labs 4b.1 y 4b.2, usar **Opción A**: los logs de la aplicación web en EC2 (Apache/Nginx) se configuran con CloudWatch Agent directamente hacia CloudWatch Logs.

---

## 4. RDS (Enhanced Monitoring)

### Requisito: Crear IAM Role

```bash
# Crear rol
aws iam create-role \
    --role-name RDSRolesMonitoring \
    --assume-role-policy-document '{
        "Version": "2012-10-17",
        "Statement": [{
            "Action": "sts:AssumeRole",
            "Principal": {"Service": "monitoring.rds.amazonaws.com"},
            "Effect": "Allow"
        }]
    }'

# Adjuntar policy
aws iam attach-role-policy \
    --role-name RDSRolesMonitoring \
    --policy-arn arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole
```

### Habilitar en RDS (Console)

1. Ir a **RDS** > **Databases**
2. Seleccionar instancia
3. **Modify**
4. En **Monitoring**:
   - Enhanced monitoring: ✅ Enable
   - Monitoring role: `RDSRolesMonitoring` (o default)
   - Granularity: 60s (para labs)
5. **Continue**
6. **Apply immediately**

### Log Groups generados

- `/aws/rds/instance/<instance-id>/os`
- `/aws/rds/instance/<instance-id>/performance-insights`
- `/aws/rds/instance/<instance-id>/processlist`

### Ver logs en CloudWatch

1. Ir a **CloudWatch** > **Logs** > **Log groups**
2. Buscar: `/aws/rds/instance/`
3. Explorar streams: `os-amazon`, `performance-insights`, etc.

---

## 5. Crear Log Groups Manualmente

Si necesitas crear Log Groups antes de que los servicios los generen:

### Por Consola

1. Ir a **CloudWatch** > **Logs** > **Log groups**
2. Clic en **Create log group**
3. Configurar:
   - Name: `/aws/ec2/application-logs`
   - Retention: 30 days
   - KMS: None (para labs)
4. Clic en **Create**

### Por AWS CLI

```bash
# EC2
aws logs create-log-group --log-group-name /aws/ec2/application-logs

# Lambda (automático, pero se puede pre-crear)
aws logs create-log-group --log-group-name /aws/lambda/production-api

# RDS (automático al habilitar, pero se puede pre-crear)
aws logs create-log-group --log-group-name /aws/rds/instance/prod-db

# Verificar
aws logs describe-log-groups --log-group-name-prefix /aws/
```

---

## 6. Verificación Centralizada

### Comprobar que todos los Log Groups existen

```bash
# Listar todos los log groups
aws logs describe-log-groups --query 'logGroups[*].[logGroupName]' --output table
```

### Log Groups esperados

| Servicio | Log Group Name |
|-----------|----------------|
| EC2 | `/aws/ec2/application-logs` |
| Lambda | `/aws/lambda/<function-name>` |
| ALB | N/A (solo S3, ver nota arriba) |
| RDS | `/aws/rds/instance/<instance-id>` |

### Probar que hay datos

```bash
# Ver streams en un log group
aws logs describe-log-streams \
    --log-group-name /aws/lambda/my-function \
    --query 'logStreams[*].[logStreamName, latestEventTimestamp]' \
    --output table

# Hacer query rápida
aws logs filter-log-events \
    --log-group-name /aws/lambda/my-function \
    --start-time $(date -d '1 hour ago' +%s000) \
    --query 'events[0:3]' \
    --output json
```

---

## Resumen: Servicios y Configuración

| Servicio | Habilitar Logs | Configuración | Log Group |
|----------|---------------|---------------|-----------|
| **EC2** | Instalar CloudWatch Agent | Crear config.json, iniciar servicio | `/aws/ec2/application-logs` |
| **Lambda** | Automático | Ninguna (logs van a `/aws/lambda/<name>`) | `/aws/lambda/<function-name>` |
| **ALB** | Access Logs hacia S3 | Crear bucket S3 + habilitar en ALB | N/A (solo S3) |
| **RDS** | Enhanced Monitoring | Modificar instancia, crear IAM role | `/aws/rds/instance/<db-id>` |

---

## Comandos de Verificación Rápida

```bash
# 1. Ver todos los log groups
aws logs describe-log-groups --query 'logGroups[*].logGroupName' --output text

# 2. Ver métricas de EC2
aws cloudwatch get-metric-statistics \
    --namespace AWS/EC2 \
    --metric-name CPUUtilization \
    --dimensions Name=InstanceId,Value=i-1234567890abcdef0 \
    --start-time $(date -d '1 hour ago' -u +%Y-%m-%dT%H:%M:%S) \
    --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
    --period 300 \
    --statistics Average

# 3. Ver funciones Lambda con X-Ray
aws lambda list-functions --query 'Functions[?TracingConfig.Mode==`Active`].FunctionName'

# 4. Ver estado de ALB
aws elbv2 describe-load-balancer-attributes \
    --load-balancer-arn arn:aws:elasticloadbalancing:... \
    --query 'Attributes[?Key==`access_logs.s3.enabled`].Value'

# 5. Ver instancias RDS con enhanced monitoring
aws rds describe-db-instances \
    --query 'DBInstances[?MonitoringRole != null].DBInstanceIdentifier'
```

---

## Siguiente paso

Una vez completada esta configuración, puedes proceder con los labs de Module-04b:

1. **Lab 4b.1**: Dashboard Personalizado → requiere EC2 con CloudWatch Agent y logs de aplicación
2. **Lab 4b.2**: CloudWatch Logs Insights → requiere logs en formato ACCESS_LOG de EC2
3. **Lab 4b.3**: CloudWatch Application Insights → requiere Resource Group con EC2, Lambda, ALB
4. **Lab 4b.4**: X-Ray Tracing → Lambda con Active tracing habilitado (automático)