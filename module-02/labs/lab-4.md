# Lab 2.4: Gestión de VPC y EC2 desde AWS CLI

## Objetivo

Replicar la infraestructura de red y compute de los Labs 2.1 y 2.2 utilizando exclusivamente AWS CLI, comprendiendo la automatización y gestión programática de recursos en AWS. El estudiante aprenderá a crear, verificar y limpiar recursos de VPC, subnets, gateways, security groups e instancias EC2 usando comandos de línea.

---

## Duración Estimada

**45 minutos**

---

## Prerrequisitos

- AWS CLI v2 instalado y configurado
- Credenciales AWS con permisos para crear VPC, EC2, S3
- jq instalado para parsear JSON (opcional pero recomendado)
- Key pair existente o permisos para crear uno
- Conocimientos básicos de línea de comandos Linux/Bash

---

## Verificación de Herramientas

**Tiempo estimado:** 5 minutos

### Verificar instalación de AWS CLI

```bash
# Verificar versión de AWS CLI
aws --version
# Output esperado: aws-cli/2.x.x

# Verificar configuración
aws configure list
# Debe mostrar Access Key, Secret Key y Region
```

### Verificar jq (opcional)

```bash
# Linux/Mac
jq --version

# Windows (PowerShell)
jq --version
```

Si jq no está instalado, se puede usar `python -m json.tool` o `aws ec2 describe-vpcs --query` directamente.

---

## Arquitectura Objetivo

```
┌─────────────────────────────────────────────────────────────┐
│                        VPC (10.0.0.0/16)                    │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              Subnet Pública (10.0.1.0/24)            │   │
│  │   ┌─────────────┐                                   │   │
│  │   │  EC2 Bastion │                                   │   │
│  │   └─────────────┘                                   │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              Subnet Privada (10.0.2.0/24)            │   │
│  │   ┌─────────────┐                                   │   │
│  │   │  EC2 App     │                                   │   │
│  │   └─────────────┘                                   │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                              │
│  ┌──────────────┐          ┌──────────────┐                │
│  │ Internet GW  │          │   NAT GW     │                │
│  └──────────────┘          └──────────────┘                │
└─────────────────────────────────────────────────────────────┘
```

---

## Pasos

### Paso 1: Configurar Variables de Entorno

**Tiempo estimado:** 5 minutos

Para facilitar la ejecución de comandos, configurar variables de entorno:

```bash
# Linux/Mac (bash/zsh)
export VPC_CIDR="10.0.0.0/16"
export PUBLIC_SUBNET_CIDR="10.0.1.0/24"
export PRIVATE_SUBNET_CIDR="10.0.2.0/24"
export AWS_REGION="us-east-1"
export AZ="us-east-1a"

# Windows (PowerShell)
$env:VPC_CIDR="10.0.0.0/16"
$env:PUBLIC_SUBNET_CIDR="10.0.1.0/24"
$env:PRIVATE_SUBNET_CIDR="10.0.2.0/24"
$env:AWS_REGION="us-east-1"
$env:AZ="us-east-1a"
```

---

### Paso 2: Crear la VPC

**Tiempo estimado:** 5 minutos

```bash
# Crear VPC y capturar el VpcId
VPC_ID=$(aws ec2 create-vpc \
  --cidr-block $VPC_CIDR \
  --query 'Vpc.VpcId' \
  --output text)

echo "VPC ID: $VPC_ID"

# Etiquetar la VPC
aws ec2 create-tags \
  --resources $VPC_ID \
  --tags Key=Name,Value=lab02-vpc-cli Key=Lab,Value=Module02
```

**Verificación:**
```bash
# Describir la VPC creada
aws ec2 describe-vpcs \
  --vpc-ids $VPC_ID \
  --query 'Vpcs[0].{ID:VpcId,CIDR:CidrBlock,State:State}'
```

---

### Paso 3: Crear las Subnets

**Tiempo estimado:** 5 minutos

```bash
# Crear subnet pública
PUBLIC_SUBNET_ID=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block $PUBLIC_SUBNET_CIDR \
  --availability-zone $AZ \
  --query 'Subnet.SubnetId' \
  --output text)

echo "Public Subnet ID: $PUBLIC_SUBNET_ID"

# Etiquetar subnet pública
aws ec2 create-tags \
  --resources $PUBLIC_SUBNET_ID \
  --tags Key=Name,Value=lab02-subnet-publica Key=Type,Value=Public

# Crear subnet privada
PRIVATE_SUBNET_ID=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block $PRIVATE_SUBNET_CIDR \
  --availability-zone $AZ \
  --query 'Subnet.SubnetId' \
  --output text)

echo "Private Subnet ID: $PRIVATE_SUBNET_ID"

# Etiquetar subnet privada
aws ec2 create-tags \
  --resources $PRIVATE_SUBNET_ID \
  --tags Key=Name,Value=lab02-subnet-privada Key=Type,Value=Private
```

**Verificación:**
```bash
# Listar subnets
aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --query 'Subnets[*].{ID:SubnetId,CIDR:CidrBlock,AZ:AvailabilityZone,Name:Tags[?Key==`Name`].Value|[0]}'
```

---

### Paso 4: Crear y Configurar el Internet Gateway

**Tiempo estimado:** 5 minutos

```bash
# Crear Internet Gateway
IGW_ID=$(aws ec2 create-internet-gateway \
  --query 'InternetGateway.InternetGatewayId' \
  --output text)

echo "Internet Gateway ID: $IGW_ID"

# Etiquetar
aws ec2 create-tags \
  --resources $IGW_ID \
  --tags Key=Name,Value=lab02-igw-cli

# Adjuntar a la VPC
aws ec2 attach-internet-gateway \
  --vpc-id $VPC_ID \
  --internet-gateway-id $IGW_ID

echo "Internet Gateway adjuntado a VPC: $VPC_ID"
```

**Verificación:**
```bash
# Describir IGW
aws ec2 describe-internet-gateways \
  --internet-gateway-ids $IGW_ID \
  --query 'InternetGateways[0].{ID:InternetGatewayId,Attachments:Attachments[*].VpcId}'
```

---

### Paso 5: Crear Elastic IP y NAT Gateway

**Tiempo estimado:** 10 minutos

```bash
# Crear Elastic IP
EIP_ALLOC_ID=$(aws ec2 allocate-address \
  --domain vpc \
  --query 'AllocationId' \
  --output text)

echo "Elastic IP Allocation ID: $EIP_ALLOC_ID"

# Etiquetar
aws ec2 create-tags \
  --resources $EIP_ALLOC_ID \
  --tags Key=Name,Value=lab02-eip-natgw

# Crear NAT Gateway en subnet pública
NATGW_ID=$(aws ec2 create-nat-gateway \
  --subnet-id $PUBLIC_SUBNET_ID \
  --allocation-id $EIP_ALLOC_ID \
  --query 'NatGateway.NatGatewayId' \
  --output text)

echo "NAT Gateway ID: $NATGW_ID"

# Etiquetar
aws ec2 create-tags \
  --resources $NATGW_ID \
  --tags Key=Name,Value=lab02-natgw-cli

# Esperar a que el NAT Gateway esté disponible
echo "Esperando que NAT Gateway esté disponible..."
aws ec2 wait nat-gateway-available \
  --nat-gateway-ids $NATGW_ID

echo "NAT Gateway disponible"
```

**Verificación:**
```bash
# Describir NAT Gateway
aws ec2 describe-nat-gateways \
  --nat-gateway-ids $NATGW_ID \
  --query 'NatGateways[0].{ID:NatGatewayId,State:State,IP:EipAddress.AllocationId}'
```

---

### Paso 6: Configurar Route Tables

**Tiempo estimado:** 5 minutos

```bash
# Crear Route Table para subnet pública
RT_PUBLIC_ID=$(aws ec2 create-route-table \
  --vpc-id $VPC_ID \
  --query 'RouteTable.RouteTableId' \
  --output text)

echo "Route Table Pública ID: $RT_PUBLIC_ID"

# Crear ruta al Internet Gateway
aws ec2 create-route \
  --route-table-id $RT_PUBLIC_ID \
  --destination-cidr-block 0.0.0.0/0 \
  --gateway-id $IGW_ID

# Asociar subnet pública con RT pública
aws ec2 associate-route-table \
  --route-table-id $RT_PUBLIC_ID \
  --subnet-id $PUBLIC_SUBNET_ID

echo "Subnet pública asociada a RT pública"

# Crear Route Table para subnet privada
RT_PRIVATE_ID=$(aws ec2 create-route-table \
  --vpc-id $VPC_ID \
  --query 'RouteTable.RouteTableId' \
  --output text)

echo "Route Table Privada ID: $RT_PRIVATE_ID"

# Crear ruta al NAT Gateway
aws ec2 create-route \
  --route-table-id $RT_PRIVATE_ID \
  --destination-cidr-block 0.0.0.0/0 \
  --nat-gateway-id $NATGW_ID

# Asociar subnet privada con RT privada
aws ec2 associate-route-table \
  --route-table-id $RT_PRIVATE_ID \
  --subnet-id $PRIVATE_SUBNET_ID

echo "Subnet privada asociada a RT privada"
```

**Verificación:**
```bash
# Listar Route Tables
aws ec2 describe-route-tables \
  --query 'RouteTables[*].{ID:RouteTableId,Name:Tags[?Key==`Name`].Value|[0],VPC:VpcId}'
```

---

### Paso 7: Crear Security Groups

**Tiempo estimado:** 5 minutos

```bash
# SG para Bastion
SG_BASTION_ID=$(aws ec2 create-security-group \
  --group-name lab02-sg-bastion-cli \
  --description "Security group for bastion host - Lab CLI" \
  --vpc-id $VPC_ID \
  --output text)

echo "Security Group Bastion ID: $SG_BASTION_ID"

# Etiquetar
aws ec2 create-tags \
  --resources $SG_BASTION_ID \
  --tags Key=Name,Value=lab02-sg-bastion-cli

# Agregar regla SSH desde cualquier lugar
aws ec2 authorize-security-group-ingress \
  --group-id $SG_BASTION_ID \
  --protocol tcp \
  --port 22 \
  --cidr 0.0.0.0/0

echo "Regla SSH agregada al SG Bastion"

# SG para instancias privadas
SG_PRIVATE_ID=$(aws ec2 create-security-group \
  --group-name lab02-sg-private-cli \
  --description "Security group for private instances - Lab CLI" \
  --vpc-id $VPC_ID \
  --output text)

echo "Security Group Private ID: $SG_PRIVATE_ID"

# Etiquetar
aws ec2 create-tags \
  --resources $SG_PRIVATE_ID \
  --tags Key=Name,Value=lab02-sg-private-cli

# Regla SSH solo desde SG del Bastion
aws ec2 authorize-security-group-ingress \
  --group-id $SG_PRIVATE_ID \
  --protocol tcp \
  --port 22 \
  --source-group $SG_BASTION_ID

# Regla HTTP desde cualquier lugar
aws ec2 authorize-security-group-ingress \
  --group-id $SG_PRIVATE_ID \
  --protocol tcp \
  --port 80 \
  --cidr 0.0.0.0/0

echo "Reglas agregadas al SG Private"
```

**Verificación:**
```bash
# Describir reglas del SG Bastion
aws ec2 describe-security-groups \
  --group-ids $SG_BASTION_ID \
  --query 'SecurityGroups[0].{Name:GroupName,Rules:IpPermissions}'
```

---

### Paso 8: Lanzar Instancia EC2

**Tiempo estimado:** 10 minutos

#### 8.1 Obtener AMI ID

```bash
# Obtener AMI ID para Amazon Linux 2
AMI_ID=$(aws ec2 describe-images \
  --owners amazon \
  --filters "Name=name,Values=amzn2-ami-hvm-*-x86_64-gp2" \
  --query 'Images[0].ImageId' \
  --output text)

echo "AMI ID: $AMI_ID"
```

#### 8.2 Verificar key pair existente o crear nuevo

```bash
# Listar key pairs existentes
aws ec2 describe-key-pairs \
  --query 'KeyPairs[*].{Name:KeyName,Fingerprint:KeyFingerprint}'

# Si no existe, crear nuevo (usar nombre del Lab 2.2 o nuevo)
KEY_PAIR_NAME="lab02-keypair"
```

#### 8.3 Lanzar Instancia Bastion

```bash
# Script de User Data para Apache básico
USER_DATA_BASTION="#!/bin/bash
yum update -y
yum install -y httpd
systemctl start httpd
systemctl enable httpd
echo '<html><head><title>Bastion Host</title></head><body><h1>Bastion Host - Lab CLI</h1></body></html>' > /var/www/html/index.html"

# Lanzar instancia bastion
BASTION_INSTANCE_ID=$(aws ec2 run-instances \
  --image-id $AMI_ID \
  --instance-type t3.micro \
  --subnet-id $PUBLIC_SUBNET_ID \
  --security-group-ids $SG_BASTION_ID \
  --key-name $KEY_PAIR_NAME \
  --associate-public-ip-address \
  --user-data "$USER_DATA_BASTION" \
  --query 'Instances[0].InstanceId' \
  --output text)

echo "Bastion Instance ID: $BASTION_INSTANCE_ID"

# Etiquetar
aws ec2 create-tags \
  --resources $BASTION_INSTANCE_ID \
  --tags Key=Name,Value=lab02-bastion-cli
```

#### 8.4 Esperar que la instancia esté corriendo

```bash
echo "Esperando que la instancia bastion esté corriendo..."
aws ec2 wait instance-running \
  --instance-ids $BASTION_INSTANCE_ID

echo "Instancia bastion corriendo"
```

#### 8.5 Obtener información de la instancia

```bash
# Obtener IP pública del bastion
BASTION_PUBLIC_IP=$(aws ec2 describe-instances \
  --instance-ids $BASTION_INSTANCE_ID \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text)

echo "Bastion Public IP: $BASTION_PUBLIC_IP"

# Obtener IP privada
BASTION_PRIVATE_IP=$(aws ec2 describe-instances \
  --instance-ids $BASTION_INSTANCE_ID \
  --query 'Reservations[0].Instances[0].PrivateIpAddress' \
  --output text)

echo "Bastion Private IP: $BASTION_PRIVATE_IP"
```

---

### Paso 9: Verificar Conectividad

**Tiempo estimado:** 5 minutos

```bash
# Describir todas las instancias
aws ec2 describe-instances \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --query 'Reservations[*].Instances[*].{ID:InstanceId,Name:Tags[?Key==`Name`].Value|[0],State:State.Name,PublicIP:PublicIpAddress,PrivateIP:PrivateIpAddress}'
```

**Verificación manual (opcional):**

1. Abrir navegador: `http://<BASTION_PUBLIC_IP>`
2. Debe aparecer "Bastion Host - Lab CLI"

---

### Paso 10: Explorar Comandos de Listing

**Tiempo estimado:** 5 minutos

```bash
# Listar VPCs con formato tabla
aws ec2 describe-vpcs \
  --query 'Vpcs[*].{ID:VpcId,CIDR:CidrBlock,Name:Tags[?Key==`Name`].Value|[0]}' \
  --output table

# Listar Subnets
aws ec2 describe-subnets \
  --query 'Subnets[*].{ID:SubnetId,CIDR:CidrBlock,AZ:AvailabilityZone,Name:Tags[?Key==`Name`].Value|[0]}' \
  --output table

# Listar Internet Gateways
aws ec2 describe-internet-gateways \
  --query 'InternetGateways[*].{ID:InternetGatewayId,Name:Tags[?Key==`Name`].Value|[0],VPC:Attachments[0].VpcId}' \
  --output table

# Listar NAT Gateways
aws ec2 describe-nat-gateways \
  --query 'NatGateways[*].{ID:NatGatewayId,State:State,Subnet:SubnetId}' \
  --output table

# Listar Security Groups
aws ec2 describe-security-groups \
  --query 'SecurityGroups[*].{Name:GroupName,ID:GroupId,VPC:VpcId}' \
  --output table

# Listar Instancias EC2
aws ec2 describe-instances \
  --query 'Reservations[*].Instances[*].{ID:InstanceId,Type:InstanceType,State:State.Name,Public:PublicIpAddress}' \
  --output table
```

---

### Paso 11: Limpieza de Recursos (Opcional)

**Tiempo estimado:** 10 minutos

** IMPORTANTE:** Ejecutar la limpieza para evitar costos.

```bash
# 1. Terminar instancias
echo "Terminando instancias..."
aws ec2 terminate-instances \
  --instance-ids $BASTION_INSTANCE_ID

aws ec2 wait instance-terminated \
  --instance-ids $BASTION_INSTANCE_ID

echo "Instancias terminadas"

# 2. Eliminar Security Groups (primero reglas dependencies)
echo "Eliminando Security Groups..."
aws ec2 delete-security-group \
  --group-id $SG_PRIVATE_ID

aws ec2 delete-security-group \
  --group-id $SG_BASTION_ID

echo "Security Groups eliminados"

# 3. Eliminar Route Tables (primero dissociations)
echo "Eliminando Route Tables..."
aws ec2 delete-route-table \
  --route-table-id $RT_PRIVATE_ID

aws ec2 delete-route-table \
  --route-table-id $RT_PUBLIC_ID

echo "Route Tables eliminadas"

# 4. Eliminar NAT Gateway
echo "Eliminando NAT Gateway..."
aws ec2 delete-nat-gateway \
  --nat-gateway-id $NATGW_ID

# Esperar eliminación
aws ec2 wait nat-gateway-deleted \
  --nat-gateway-ids $NATGW_ID

# Liberar Elastic IP
aws ec2 release-address \
  --allocation-id $EIP_ALLOC_ID

echo "NAT Gateway y EIP eliminados"

# 5. Desvincular y eliminar Internet Gateway
echo "Eliminando Internet Gateway..."
aws ec2 detach-internet-gateway \
  --vpc-id $VPC_ID \
  --internet-gateway-id $IGW_ID

aws ec2 delete-internet-gateway \
  --internet-gateway-id $IGW_ID

echo "Internet Gateway eliminado"

# 6. Eliminar Subnets
echo "Eliminando Subnets..."
aws ec2 delete-subnet \
  --subnet-id $PUBLIC_SUBNET_ID

aws ec2 delete-subnet \
  --subnet-id $PRIVATE_SUBNET_ID

echo "Subnets eliminadas"

# 7. Eliminar VPC
echo "Eliminando VPC..."
aws ec2 delete-vpc \
  --vpc-id $VPC_ID

echo "VPC eliminada"
echo "Cleanup completado"
```

---

## Criterios de Verificación

Al completar este laboratorio, el estudiante debe ser capaz de:

- [ ] Crear una VPC usando AWS CLI con CIDR block especificado
- [ ] Crear subnets públicas y privadas con tags apropiados
- [ ] Crear y adjuntar un Internet Gateway a la VPC
- [ ] Crear una Elastic IP para el NAT Gateway
- [ ] Crear un NAT Gateway en la subnet pública
- [ ] Configurar Route Tables con rutas a IGW y NAT Gateway
- [ ] Asociar subnets con sus Route Tables correspondientes
- [ ] Crear Security Groups con reglas de entrada (SSH, HTTP)
- [ ] Autorizar reglas de seguridad usando source-group
- [ ] Obtener AMI ID para Amazon Linux 2
- [ ] Lanzar instancias EC2 con user data script
- [ ] Verificar que instancias tienen IPs públicas asignadas
- [ ] Usar `aws ec2 wait` para esperar estados de recursos
- [ ] Listar y describir recursos usando queries JSON
- [ ] Eliminar recursos en el orden correcto para evitar dependencias
- [ ] Limpiar todos los recursos creados

---

## Comandos de Referencia Rápida

```bash
# VPC
aws ec2 create-vpc --cidr-block 10.0.0.0/16
aws ec2 describe-vpcs
aws ec2 delete-vpc --vpc-id vpc-xxxxx

# Subnets
aws ec2 create-subnet --vpc-id vpc-xxxx --cidr-block 10.0.1.0/24 --availability-zone us-east-1a
aws ec2 describe-subnets --filters "Name=vpc-id,Values=vpc-xxxx"
aws ec2 delete-subnet --subnet-id subnet-xxxx

# Internet Gateway
aws ec2 create-internet-gateway
aws ec2 attach-internet-gateway --vpc-id vpc-xxxx --internet-gateway-id igw-xxxx
aws ec2 delete-internet-gateway --internet-gateway-id igw-xxxx

# NAT Gateway
aws ec2 allocate-address --domain vpc
aws ec2 create-nat-gateway --subnet-id subnet-xxxx --allocation-id eipalloc-xxxx
aws ec2 delete-nat-gateway --nat-gateway-id nat-xxxx

# Route Tables
aws ec2 create-route-table --vpc-id vpc-xxxx
aws ec2 create-route --route-table-id rtb-xxxx --destination-cidr-block 0.0.0.0/0 --gateway-id igw-xxxx
aws ec2 associate-route-table --route-table-id rtb-xxxx --subnet-id subnet-xxxx
aws ec2 delete-route-table --route-table-id rtb-xxxx

# Security Groups
aws ec2 create-security-group --group-name nombre --vpc-id vpc-xxxx --description "desc"
aws ec2 authorize-security-group-ingress --group-id sg-xxxx --protocol tcp --port 22 --cidr 0.0.0.0/0
aws ec2 delete-security-group --group-id sg-xxxx

# EC2
aws ec2 run-instances --image-id ami-xxxx --instance-type t3.micro --subnet-id subnet-xxxx --key-name mi-key
aws ec2 describe-instances
aws ec2 terminate-instances --instance-ids i-xxxx
```

---

## Errores Comunes y Soluciones

| Error | Causa | Solución |
|-------|-------|----------|
| `InvalidSubnetRange` | CIDR se solapa con VPC existente | Usar rango diferente, verificar que no haya overlap |
| `ResourceAlreadyAssociated` | IGW ya está adjuntado a otra VPC | Verificar estado actual con `describe-internet-gateways` |
| `AuthFailure` | Credenciales inválidas o expiradas | Ejecutar `aws configure` y verificar credenciales |
| `InstanceLimitExceeded` | Límite de instancias en la cuenta | Request limit increase o usar región diferente |
| `NatGatewayNotFound` | Subnet ID incorrecto | Verificar que la subnet existe y está en la VPC correcta |
| `UnauthorizedOperation` | IAM permissions insuficientes | Verificar que el usuario tiene permisos para crear EC2 |
| `DependencyViolation` | Intentar eliminar recurso con dependencias | Eliminar recursos dependientes primero |
| `request timed out` | Instancia tarda en inicializar | Esperar con `aws ec2 wait instance-running` |

---

## Referencias

- [AWS CLI Reference for EC2](https://docs.aws.amazon.com/cli/latest/reference/ec2/)
- [EC2 User Guide - Command Line](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/using-cli.html)
- [VPC CLI Reference](https://docs.aws.amazon.com/cli/latest/reference/ec2/index.html)
- [jq Manual](https://stedolan.github.io/jq/manual/)
