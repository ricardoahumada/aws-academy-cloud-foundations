# Lab 8.2: Implementar VPC Endpoints (PrivateLink) para Acceso Privado a S3 y DynamoDB

## Objetivo

Crear VPC Endpoints (Gateway e Interface) para acceder a servicios AWS (S3 y DynamoDB) de forma privada sin usar NAT ni acceso a internet.

## Duración Estimada

30 minutos

## Prerrequisitos

- VPC con subnets privadas que no tengan NAT Gateway
- IAM role con permisos para crear endpoints y buckets S3
- AWS CLI configurado
- Bucket S3 existente para pruebas
- Tabla DynamoDB existente para pruebas

## Recursos Necesarios

| Recurso | Detalles |
|---------|----------|
| VPC | `my-vpc` con CIDR `10.0.0.0/16` |
| Subnets privadas | `subnet-private-1` (az-1a), `subnet-private-2` (az-1b) |
| Route Table | `rtb-private` asociada a las subnets privadas |
| Security Group | `sg-private` para las ENIs de interface endpoints |
| Bucket S3 | `my-bucket-lab-82` para pruebas |
| Tabla DynamoDB | `MyTable-lab-82` para pruebas |

## Diagrama de Arquitectura

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                                 VPC (10.0.0.0/16)                             │
│                                                                                │
│   ┌────────────────────────────────────────────────────────────────────────┐  │
│   │                         Route Table (rtb-private)                       │  │
│   │   10.0.0.0/16  ──► local                                               │  │
│   │   pl-xxxxxxxx  ──► vpce-xxxxxxxx  (S3 Gateway Endpoint)               │  │
│   │   vpce-xxxxxxxx ──► eni-xxxxxxxx  (DynamoDB Interface Endpoint)       │  │
│   └────────────────────────────────────────────────────────────────────────┘  │
│                                                                                │
│   ┌────────────────────────────────────────────────────────────────────────┐  │
│   │  Private Subnet                                                         │  │
│   │                                                                          │  │
│   │   ┌──────────────┐         ┌─────────────────────┐                     │  │
│   │   │  EC2 Instance │────────│ S3 Gateway Endpoint │─────────► S3       │  │
│   │   │  (sin acceso  │         │ vpce-xxxxxxxx       │                     │  │
│   │   │   a internet) │         └─────────────────────┘                     │  │
│   │   │              │────────│ DynamoDB Interface   │─────────► DynamoDB  │  │
│   │   └──────────────┘         │ Endpoint             │                     │  │
│   │                              │ eni-xxxxxxxx        │                     │  │
│   │                              └─────────────────────┘                     │  │
│   └────────────────────────────────────────────────────────────────────────┘  │
│                                                                                │
└──────────────────────────────────────────────────────────────────────────────┘
```

## Pasos

### Fase 1: Crear Gateway Endpoint para S3

**Paso 1.1: Identificar la VPC y Route Table**

```bash
# Obtener ID de VPC
aws ec2 describe-vpcs \
    --filters "Name=tag:Name,Values=my-vpc" \
    --query 'Vpcs[0].VpcId' \
    --output text

# Obtener ID de Route Table privada
aws ec2 describe-route-tables \
    --filters "Name=tag:Name,Values=rtb-private" \
    --query 'RouteTables[0].RouteTableId' \
    --output text
```

**Paso 1.2: Crear Gateway Endpoint para S3**

```bash
# Crear Gateway Endpoint para S3
aws ec2 create-vpc-endpoint \
    --vpc-id vpc-xxxxxxxx \
    --service-name com.amazonaws.us-east-1.s3 \
    --vpc-endpoint-type Gateway \
    --route-table-ids rtb-xxxxxxxx \
    --tag-specifications 'ResourceType=vpc-endpoint,Tags=[{Key=Name,Value=endpoint-s3-private},{Key=Service,Value=S3}]'
```

**Paso 1.3: Verificar el Gateway Endpoint**

```bash
# Verificar estado del endpoint
aws ec2 describe-vpc-endpoints \
    --vpc-endpoint-ids vpce-xxxxxxxx \
    --query 'VpcEndpoints[0].State'

# Verificar que la ruta fue agregada automáticamente
aws ec2 describe-route-tables \
    --route-table-id rtb-xxxxxxxx \
    --query 'RouteTables[0].Routes'
```

---

### Fase 2: Configurar Policy para Gateway Endpoint

**Paso 2.1: Obtener información del bucket S3**

```bash
# Listar buckets y verificar existencia
aws s3 ls

# Obtener ARN del bucket
aws s3api get-bucket-location --bucket my-bucket-lab-82 --query 'LocationConstraint'
```

**Paso 2.2: Crear política de acceso al bucket**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowVPCEndpointAccess",
      "Effect": "Allow",
      "Principal": "*",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::my-bucket-lab-82",
        "arn:aws:s3:::my-bucket-lab-82/*"
      ],
      "Condition": {
        "StringEquals": {
          "aws:sourceVpce": "vpce-xxxxxxxx"
        }
      }
    }
  ]
}
```

**Paso 2.3: Aplicar política al bucket**

```bash
# Guardar política en archivo
cat > /tmp/s3-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowVPCEndpointAccess",
      "Effect": "Allow",
      "Principal": "*",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::my-bucket-lab-82",
        "arn:aws:s3:::my-bucket-lab-82/*"
      ],
      "Condition": {
        "StringEquals": {
          "aws:sourceVpce": "vpce-xxxxxxxx"
        }
      }
    }
  ]
}
EOF

# Aplicar política al bucket
aws s3api put-bucket-policy \
    --bucket my-bucket-lab-82 \
    --policy file:///tmp/s3-policy.json
```

---

### Fase 3: Crear Interface Endpoint para DynamoDB

**Paso 3.1: Obtener ID del Security Group**

```bash
# Obtener Security Group para subnets privadas
aws ec2 describe-security-groups \
    --filters "Name=tag:Name,Values=sg-private" \
    --query 'SecurityGroups[0].GroupId' \
    --output text
```

**Paso 3.2: Crear Interface Endpoint para DynamoDB**

```bash
# Crear Interface Endpoint para DynamoDB
aws ec2 create-vpc-endpoint \
    --vpc-id vpc-xxxxxxxx \
    --service-name com.amazonaws.us-east-1.dynamodb \
    --vpc-endpoint-type Interface \
    --subnet-ids subnet-xxxxxxxx subnet-yyyyyyyy \
    --security-group-ids sg-zzzzzzzz \
    --tag-specifications 'ResourceType=vpc-endpoint,Tags=[{Key=Name,Value=endpoint-dynamodb-private},{Key=Service,Value=DynamoDB}]'
```

**Paso 3.3: Verificar Interface Endpoint**

```bash
# Verificar estado del endpoint
aws ec2 describe-vpc-endpoints \
    --vpc-endpoint-ids vpce-yyyyyyyy \
    --query 'VpcEndpoints[0].State'

# Ver las ENIs creadas automáticamente
aws ec2 describe-vpc-endpoints \
    --vpc-endpoint-ids vpce-yyyyyyyy \
    --query 'VpcEndpoints[0].DnsEntries'
```

---

### Fase 4: Configurar acceso a DynamoDB (opcional - policy)

**Paso 4.1: Crear política para tabla DynamoDB**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowDynamoDBViaEndpoint",
      "Effect": "Allow",
      "Principal": "*",
      "Action": [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:Query",
        "dynamodb:Scan"
      ],
      "Resource": "arn:aws:dynamodb:us-east-1:123456789012:table/MyTable-lab-82",
      "Condition": {
        "StringEquals": {
          "aws:sourceVpce": "vpce-yyyyyyyy"
        }
      }
    }
  ]
}
```

**Paso 4.2: Aplicar política a tabla DynamoDB (si aplica)**

```bash
# Obtener ARN de la tabla
aws dynamodb describe-table \
    --table-name MyTable-lab-82 \
    --query 'Table.TableArn'

# Aplicar Resource Policy a la tabla DynamoDB
# Requiere DynamoDB con Resource Policy habilitado (disponible desde 2023)
TABLE_ARN=$(aws dynamodb describe-table \
    --table-name MyTable-lab-82 \
    --query 'Table.TableArn' --output text)

aws dynamodb put-resource-policy \
    --resource-arn "$TABLE_ARN" \
    --policy file:///tmp/dynamodb-policy.json
```

> **Nota:** `put-resource-policy` es el comando correcto para aplicar políticas de recurso a tablas DynamoDB. La API de Resource Policy para DynamoDB está disponible desde noviembre 2023.
> 
> Para acceso privado a DynamoDB desde VPC, prefiere un **Gateway Endpoint** (gratuito) sobre un Interface Endpoint (tiene coste por hora). Los Gateway Endpoints para DynamoDB y S3 no requieren política de recurso en la tabla.

---

### Fase 5: Verificar Acceso Privado

**Paso 5.1: Lanzar EC2 en subnet privada**

```bash
# Lanzar EC2 en subnet privada
aws ec2 run-instances \
    --image-id $(aws ec2 describe-images --owners amazon --filters 'Name=name,Values=al2023-ami-*-x86_64' --query 'sort_by(Images,&CreationDate)[-1].ImageId' --output text) \
    --instance-type t2.micro \
    --subnet-id subnet-xxxxxxxx \
    --security-group-ids sg-zzzzzzzz \
    --iam-instance-profile Name=EC2S3AccessRole \
    --key-name my-key-pair \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=EC2-Private-No-NAT}]'
```

**Paso 5.2: Verificar conectividad a S3 vía Gateway Endpoint**

```bash
# Conectar a EC2 vía Session Manager o bastion
ssh -i my-key-pair.pem ec2-user@<EC2-PRIVATE-IP>

# Desde EC2, verificar acceso a S3 (debe funcionar sin internet)
aws s3 ls
# Debe listar buckets sin error

aws s3 ls s3://my-bucket-lab-82/
# Debe listar contenido del bucket

# Crear objeto de prueba
echo "test data" | aws s3 cp - s3://my-bucket-lab-82/test.txt
# Debe subir sin error
```

**Paso 5.3: Verificar conectividad a DynamoDB vía Interface Endpoint**

```bash
# Desde EC2, verificar acceso a DynamoDB
aws dynamodb list-tables
# Debe listar tablas sin error

# Escribir y leer de tabla
aws dynamodb put-item \
    --table-name MyTable-lab-82 \
    --item '{"id": {"S": "test-1"}, "data": {"S": "Hello from VPC Endpoint"}}'

aws dynamodb get-item \
    --table-name MyTable-lab-82 \
    --key '{"id": {"S": "test-1"}}'
```

**Paso 5.4: Verificar que el tráfico NO sale a internet**

```bash
# Verificar que no hay NAT ni internet gateway disponible
# (el curl fallará con timeout, confirmando ausencia de internet)
curl --max-time 5 https://ipinfo.io/ip
# Output esperado: timeout o "Could not connect" - confirma que no hay salida a internet

# Verificar endpoints activos
aws ec2 describe-vpc-endpoints \
    --vpc-endpoint-ids vpce-xxxxxxxx vpce-yyyyyyyy \
    --query 'VpcEndpoints[*].{Id:VpcEndpointId,State:State,ServiceName:ServiceName}'
```

---

## Verificación

Al finalizar el lab, el estudiante debe poder verificar cada uno de los siguientes puntos:

| # | Criterio | Comando de Verificación | Resultado Esperado |
|---|----------|-------------------------|---------------------|
| 1 | Gateway Endpoint S3 creado | `aws ec2 describe-vpc-endpoints --query 'VpcEndpoints[?ServiceName==\`com.amazonaws.us-east-1.s3\`]'` | Estado `available` |
| 2 | Ruta a S3 en Route Table | `aws ec2 describe-route-tables --route-table-id rtb-xxxxxxxx --query 'Routes'` | Destino `pl-xxxxxxxx`指向 S3 |
| 3 | Interface Endpoint DynamoDB creado | `aws ec2 describe-vpc-endpoints --query 'VpcEndpoints[?ServiceName==\`com.amazonaws.us-east-1.dynamodb\`]'` | Estado `available` |
| 4 | Acceso S3 desde EC2 privada | `aws s3 ls` desde EC2 | Lista de buckets |
| 5 | Acceso DynamoDB desde EC2 privada | `aws dynamodb list-tables` desde EC2 | Lista de tablas |
| 6 | IP privada al verificar IP externa | `curl https://ipinfo.io/ip` | IP privada AWS |

---

## Errores Comunes y Soluciones

### Error 1: "Endpoint not found" al crear endpoint

**Causa:** Nombre de servicio incorrecto o región no válida.

**Solución:**
```bash
# Listar servicios disponibles en la región
aws ec2 describe-vpc-endpoint-services \
    --query 'ServiceNames'

# Usar nombre completo con región
aws ec2 create-vpc-endpoint \
    --service-name com.amazonaws.us-east-1.s3
```

### Error 2: "Route table already has a route" para S3

**Causa:** Ya existe una ruta que cubre el CIDR de S3 (por ejemplo, 0.0.0.0/0 a NAT).

**Solución:**
```bash
# Verificar rutas existentes
aws ec2 describe-route-tables \
    --route-table-id rtb-xxxxxxxx

# Eliminar NAT Gateway route antes de agregar endpoint
aws ec2 delete-route \
    --route-table-id rtb-xxxxxxxx \
    --destination-cidr-block 0.0.0.0/0
```

### Error 3: "Access Denied" al acceder a S3 desde EC2

**Causa:** IAM role no tiene permisos o política de bucket lo impide.

**Solución:**
```bash
# Verificar que EC2 tiene IAM role
aws ec2 describe-instances \
    --instance-ids i-xxxxxxxx \
    --query 'Reservations[0].Instances[0].IamInstanceProfile'

# Verificar permisos del bucket
aws s3api get-bucket-policy --bucket my-bucket-lab-82

# Verificar que el endpoint policy permite el acceso
aws ec2 describe-vpc-endpoints \
    --vpc-endpoint-ids vpce-xxxxxxxx \
    --query 'VpcEndpoints[0].PolicyDocument'
```

### Error 4: DynamoDB endpoint no responde

**Causa:** Security Group no permite tráfico entrante en puerto 443.

**Solución:**
```bash
# Verificar que el SG permite tráfico HTTPS (443)
aws ec2 describe-security-groups \
    --group-id sg-zzzzzzzz \
    --query 'SecurityGroups[0].IpPermissions'

# Agregar regla si es necesario
aws ec2 authorize-security-group-ingress \
    --group-id sg-zzzzzzzz \
    --ip-permissions '[{"IpProtocol": "tcp", "FromPort": 443, "ToPort": 443, "IpRanges": [{"CidrIp": "10.0.0.0/16"}]}]'
```

---

## Limpieza de Recursos

```bash
# Eliminar Gateway Endpoint para S3 y Interface Endpoint para DynamoDB
aws ec2 delete-vpc-endpoints \
    --vpc-endpoint-ids vpce-xxxxxxxx vpce-yyyyyyyy

# Eliminar política del bucket
aws s3api delete-bucket-policy --bucket my-bucket-lab-82

# Eliminar objetos de prueba del bucket
aws s3 rm s3://my-bucket-lab-82/test.txt

# Eliminar items de prueba de DynamoDB
aws dynamodb delete-item \
    --table-name MyTable-lab-82 \
    --key '{"id": {"S": "test-1"}}'
```

---

## Referencias

- [VPC Endpoints Documentation](https://docs.aws.amazon.com/vpc/latest/privatelink/)
- [Gateway Endpoints for S3](https://docs.aws.amazon.com/vpc/latest/privatelink/gateway-endpoints.html)
- [Interface Endpoints for DynamoDB](https://docs.aws.amazon.com/vpc/latest/privatelink/interface-endpoints.html)
