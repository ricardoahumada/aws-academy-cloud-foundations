# Lab 4.3: Crear VPC con CloudFormation (Opcional)

## Objetivo

Crear la infraestructura de VPC completa (VPC, subnets, Internet Gateway, NAT Gateway, Route Tables) utilizando AWS CloudFormation como Infrastructure as Code.

Al finalizar, comprenderás cómo:
- Escribir templates de CloudFormation en formato YAML
- Crear stacks de infraestructura completos
- Actualizar stacks existentes con cambios
- Detectar drifts entre el estado actual y el template

## Duración estimada

45 minutos

## Prerrequisitos

- AWS CLI configurado con permisos para CloudFormation, EC2, VPC
- Credenciales con permisos para crear recursos de red
- Conocimientos básicos de YAML

## Plantilla objetivo

```
┌─────────────────────────────────────────────────────────────────┐
│                         mi-vpc (10.0.0.0/16)                    │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │              Public Subnets (10.0.1.0/24, 10.0.2.0/24)   │   │
│  │  ┌─────────┐  ┌─────────┐  ┌─────────┐                   │   │
│  │  │ IGW     │  │ Bastion │  │ NAT     │                   │   │
│  │  │         │  │ Host    │  │ Gateway │                   │   │
│  │  └─────────┘  └─────────┘  └─────────┘                   │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │              Private Subnets (10.0.11.0/24, 10.0.12.0/24)│   │
│  │  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐      │   │
│  │  │ Web     │  │ App     │  │ DB      │  │ DB      │      │   │
│  │  │ Tier    │  │ Tier    │  │ (AZ-1)  │  │ (AZ-2)  │      │   │
│  │  └─────────┘  └─────────┘  └─────────┘  └─────────┘      │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

---

## Paso 1: Crear el Template de CloudFormation

### 1.1 Crear archivo de template

Crear un archivo `vpc-template.yaml` con el siguiente contenido:

```yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: >
  VPC Network Stack - Crea una VPC con subnets públicas y privadas
  en múltiples AZs, Internet Gateway, NAT Gateway y Route Tables.

Parameters:
  EnvironmentName:
    Type: String
    Default: production
    Description: Nombre del ambiente (usado para tagging)
  
  VPCCidr:
    Type: String
    Default: 10.0.0.0/16
    Description: CIDR block para la VPC
  
  PublicSubnet1CIDR:
    Type: String
    Default: 10.0.1.0/24
    Description: CIDR para la subnet pública 1
  
  PublicSubnet2CIDR:
    Type: String
    Default: 10.0.2.0/24
    Description: CIDR para la subnet pública 2
  
  PrivateSubnet1CIDR:
    Type: String
    Default: 10.0.11.0/24
    Description: CIDR para la subnet privada 1
  
  PrivateSubnet2CIDR:
    Type: String
    Default: 10.0.12.0/24
    Description: CIDR para la subnet privada 2

Resources:
  # VPC
  VPC:
    Type: AWS::EC2::VPC
    Properties:
      CidrBlock: !Ref VPCCidr
      EnableDnsHostnames: true
      EnableDnsSupport: true
      Tags:
        - Key: Name
          Value: !Sub ${EnvironmentName}-vpc
        - Key: Environment
          Value: !Ref EnvironmentName

  # Internet Gateway
  InternetGateway:
    Type: AWS::EC2::InternetGateway
    Properties:
      Tags:
        - Key: Name
          Value: !Sub ${EnvironmentName}-igw

  # Attach IGW to VPC
  AttachGateway:
    Type: AWS::EC2::VPCGatewayAttachment
    Properties:
      VpcId: !Ref VPC
      InternetGatewayId: !Ref InternetGateway

  # Public Subnet 1 (AZ-1)
  PublicSubnet1:
    Type: AWS::EC2::Subnet
    Properties:
      VpcId: !Ref VPC
      CidrBlock: !Ref PublicSubnet1CIDR
      AvailabilityZone: !Select [0, !GetAZs '']
      MapPublicIpOnLaunch: true
      Tags:
        - Key: Name
          Value: !Sub ${EnvironmentName}-public-subnet-az1
        - Key: Tier
          Value: Public

  # Public Subnet 2 (AZ-2)
  PublicSubnet2:
    Type: AWS::EC2::Subnet
    Properties:
      VpcId: !Ref VPC
      CidrBlock: !Ref PublicSubnet2CIDR
      AvailabilityZone: !Select [1, !GetAZs '']
      MapPublicIpOnLaunch: true
      Tags:
        - Key: Name
          Value: !Sub ${EnvironmentName}-public-subnet-az2
        - Key: Tier
          Value: Public

  # Private Subnet 1 (AZ-1)
  PrivateSubnet1:
    Type: AWS::EC2::Subnet
    Properties:
      VpcId: !Ref VPC
      CidrBlock: !Ref PrivateSubnet1CIDR
      AvailabilityZone: !Select [0, !GetAZs '']
      MapPublicIpOnLaunch: false
      Tags:
        - Key: Name
          Value: !Sub ${EnvironmentName}-private-subnet-az1
        - Key: Tier
          Value: Private

  # Private Subnet 2 (AZ-2)
  PrivateSubnet2:
    Type: AWS::EC2::Subnet
    Properties:
      VpcId: !Ref VPC
      CidrBlock: !Ref PrivateSubnet2CIDR
      AvailabilityZone: !Select [1, !GetAZs '']
      MapPublicIpOnLaunch: false
      Tags:
        - Key: Name
          Value: !Sub ${EnvironmentName}-private-subnet-az2
        - Key: Tier
          Value: Private

  # Elastic IP for NAT Gateway
  NatEIP:
    Type: AWS::EC2::EIP
    DependsOn: AttachGateway
    Properties:
      Domain: vpc
      Tags:
        - Key: Name
          Value: !Sub ${EnvironmentName}-nat-eip

  # NAT Gateway (en Public Subnet 1)
  NatGateway:
    Type: AWS::EC2::NatGateway
    Properties:
      AllocationId: !GetAtt NatEIP.AllocationId
      SubnetId: !Ref PublicSubnet1
      Tags:
        - Key: Name
          Value: !Sub ${EnvironmentName}-natgw

  # Public Route Table
  PublicRouteTable:
    Type: AWS::EC2::RouteTable
    Properties:
      VpcId: !Ref VPC
      Tags:
        - Key: Name
          Value: !Sub ${EnvironmentName}-public-rt

  # Route to IGW (Public)
  PublicRoute:
    Type: AWS::EC2::Route
    DependsOn: AttachGateway
    Properties:
      RouteTableId: !Ref PublicRouteTable
      DestinationCidrBlock: 0.0.0.0/0
      GatewayId: !Ref InternetGateway

  # Associate Public Subnet 1 with Public Route Table
  PublicSubnet1RouteTableAssociation:
    Type: AWS::EC2::SubnetRouteTableAssociation
    Properties:
      SubnetId: !Ref PublicSubnet1
      RouteTableId: !Ref PublicRouteTable

  # Associate Public Subnet 2 with Public Route Table
  PublicSubnet2RouteTableAssociation:
    Type: AWS::EC2::SubnetRouteTableAssociation
    Properties:
      SubnetId: !Ref PublicSubnet2
      RouteTableId: !Ref PublicRouteTable

  # Private Route Table (para Private Subnet 1)
  PrivateRouteTable1:
    Type: AWS::EC2::RouteTable
    Properties:
      VpcId: !Ref VPC
      Tags:
        - Key: Name
          Value: !Sub ${EnvironmentName}-private-rt-az1

  # Route to NAT Gateway (Private)
  PrivateRoute1:
    Type: AWS::EC2::Route
    Properties:
      RouteTableId: !Ref PrivateRouteTable1
      DestinationCidrBlock: 0.0.0.0/0
      NatGatewayId: !Ref NatGateway

  # Associate Private Subnet 1 with Private Route Table
  PrivateSubnet1RouteTableAssociation:
    Type: AWS::EC2::SubnetRouteTableAssociation
    Properties:
      SubnetId: !Ref PrivateSubnet1
      RouteTableId: !Ref PrivateRouteTable1

  # Associate Private Subnet 2 with Private Route Table
  # Nota: Para alta disponibilidad, se recomienda un NAT Gateway por AZ
  PrivateSubnet2RouteTableAssociation:
    Type: AWS::EC2::SubnetRouteTableAssociation
    Properties:
      SubnetId: !Ref PrivateSubnet2
      RouteTableId: !Ref PrivateRouteTable1

Outputs:
  VPCId:
    Description: ID de la VPC creada
    Value: !Ref VPC
    Export:
      Name: !Sub ${EnvironmentName}-vpc-id

  VPCCidr:
    Description: CIDR de la VPC
    Value: !Ref VPCCidr
    Export:
      Name: !Sub ${EnvironmentName}-vpc-cidr

  PublicSubnet1:
    Description: ID de la subnet pública 1
    Value: !Ref PublicSubnet1
    Export:
      Name: !Sub ${EnvironmentName}-public-subnet-az1

  PublicSubnet2:
    Description: ID de la subnet pública 2
    Value: !Ref PublicSubnet2
    Export:
      Name: !Sub ${EnvironmentName}-public-subnet-az2

  PrivateSubnet1:
    Description: ID de la subnet privada 1
    Value: !Ref PrivateSubnet1
    Export:
      Name: !Sub ${EnvironmentName}-private-subnet-az1

  PrivateSubnet2:
    Description: ID de la subnet privada 2
    Value: !Ref PrivateSubnet2
    Export:
      Name: !Sub ${EnvironmentName}-private-subnet-az2

  NatGateway:
    Description: ID del NAT Gateway
    Value: !Ref NatGateway
    Export:
      Name: !Sub ${EnvironmentName}-natgateway-id
```

---

## Paso 2: Crear el Stack

### 2.1 Validar el template

```bash
# Validar sintaxis del template
aws cloudformation validate-template \
  --template-body file://vpc-template.yaml
```

### 2.2 Crear el stack

```bash
# Crear el stack
aws cloudformation create-stack \
  --stack-name mi-vpc-stack \
  --template-body file://vpc-template.yaml \
  --parameters ParameterKey=EnvironmentName,ParameterValue=production \
  --capabilities CAPABILITY_IAM \
  --output json

# Esperar a que se cree el stack
aws cloudformation wait stack-create-complete \
  --stack-name mi-vpc-stack

# Verificar estado
aws cloudformation describe-stacks \
  --stack-name mi-vpc-stack \
  --query 'Stacks[0].StackStatus'
```

---

## Paso 3: Verificar Recursos Creados

### 3.1 Listar recursos generados

```bash
# Ver todos los recursos del stack
aws cloudformation list-stack-resources \
  --stack-name mi-vpc-stack \
  --query 'StackResourceSummaries[*].{LogicalId:LogicalResourceId,PhysicalId:PhysicalResourceId,Type:ResourceType,Status:ResourceStatus}'

# Obtener outputs del stack
aws cloudformation describe-stacks \
  --stack-name mi-vpc-stack \
  --query 'Stacks[0].Outputs'
```

### 3.2 Verificar en consola VPC

1. Ir a **Services** > **VPC** > **Your VPCs**
2. Verificar que existe `production-vpc`
3. Ir a **Subnets** y verificar las 4 subnets
4. Ir a **Internet Gateways** y verificar el IGW asociado
5. Ir a **NAT Gateways** y verificar el NAT Gateway
6. Ir a **Route Tables** y verificar las tablas de rutas

---

## Paso 4: Hacer Cambios al Template

### 4.1 Modificar el template

Supongamos que queremos agregar una tercera AZ (agregar `PrivateSubnet3` y `PublicSubnet3`):

```yaml
  # Agregar al Parameters
  PublicSubnet3CIDR:
    Type: String
    Default: 10.0.3.0/24
  
  PrivateSubnet3CIDR:
    Type: String
    Default: 10.0.13.0/24

  # Agregar recursos
  PublicSubnet3:
    Type: AWS::EC2::Subnet
    Properties:
      VpcId: !Ref VPC
      CidrBlock: !Ref PublicSubnet3CIDR
      AvailabilityZone: !Select [2, !GetAZs '']
      MapPublicIpOnLaunch: true
      Tags:
        - Key: Name
          Value: !Sub ${EnvironmentName}-public-subnet-az3

  PrivateSubnet3:
    Type: AWS::EC2::Subnet
    Properties:
      VpcId: !Ref VPC
      CidrBlock: !Ref PrivateSubnet3CIDR
      AvailabilityZone: !Select [2, !GetAZs '']
      Tags:
        - Key: Name
          Value: !Sub ${EnvironmentName}-private-subnet-az3

  # Asociar con route tables
  PublicSubnet3RouteTableAssociation:
    Type: AWS::EC2::SubnetRouteTableAssociation
    Properties:
      SubnetId: !Ref PublicSubnet3
      RouteTableId: !Ref PublicRouteTable

  PrivateSubnet3RouteTableAssociation:
    Type: AWS::EC2::SubnetRouteTableAssociation
    Properties:
      SubnetId: !Ref PrivateSubnet3
      RouteTableId: !Ref PrivateRouteTable1
```

### 4.2 Actualizar el stack

```bash
# Actualizar el stack con el nuevo template
aws cloudformation update-stack \
  --stack-name mi-vpc-stack \
  --template-body file://vpc-template.yaml \
  --parameters ParameterKey=EnvironmentName,ParameterValue=production \
  --capabilities CAPABILITY_IAM

# Esperar actualización
aws cloudformation wait stack-update-complete \
  --stack-name mi-vpc-stack
```

---

## Paso 5: Detectar Drift

### 5.1 Iniciar drift detection

```bash
# Iniciar drift detection
aws cloudformation detect-stack-drift \
  --stack-name mi-vpc-stack

# Verificar estado
aws cloudformation describe-stack-drift-detection-status \
  --stack-name mi-vpc-stack
```

### 5.2 Obtener resultados de drift

```bash
# Obtener recursos con drift
aws cloudformation describe-stack-resource-drifts \
  --stack-name mi-vpc-stack \
  --query 'StackResourceDrifts[*].{LogicalId:LogicalResourceId,PhysicalId:PhysicalResourceId,DriftStatus:StackResourceDriftStatus,Difference:Differences}'
```

### 5.3 Escenarios de drift comunes

| Cambio manual | Efecto en drift |
|--------------|-----------------|
| Eliminar un Security Group | Drift detectado |
| Cambiar regla de Security Group | Drift detectado |
| Modificar subnet CIDR manualmente | Drift detectado |
| Agregar tag manualmente | Drift detectado |

---

## Paso 6: Eliminar el Stack

### 6.1 Eliminar recursos del stack

```bash
# Antes de eliminar, verificar que no haya recursos dependientes
aws cloudformation delete-stack \
  --stack-name mi-vpc-stack

# Esperar eliminación completa
aws cloudformation wait stack-delete-complete \
  --stack-name mi-vpc-stack

# Verificar
aws cloudformation describe-stacks \
  --stack-name mi-vpc-stack
# Debe mostrar error (stack no existe)
```

---

## Verificación Final

Al completar este lab, debes ser capaz de:

- [ ] Escribir un template de CloudFormation válido en YAML
- [ ] Crear un stack de CloudFormation
- [ ] Verificar los recursos creados
- [ ] Actualizar un stack existente con cambios
- [ ] Detectar drifts entre el template y el estado actual
- [ ] Eliminar un stack y todos sus recursos

---

## Errores Comunes y Soluciones

| Error | Causa | Solución |
|-------|-------|----------|
| `Template validation error` | Sintaxis YAML incorrecta | Usar `validate-template` antes de crear |
| `Resource already exists` | Stack previamente creado | Eliminar stack existente o usar otro nombre |
| `Waiting for stack create-complete timeout` | Recursos tardan en crearse | Usar `--timeout-in-minutes 30` o esperar más |
| `ROLLBACK_COMPLETE` | Error durante creación | Revisar eventos del stack: `describe-stack-events` |
| `NatGateway.eip` - Dependency not satisfied | IGW no attached aún | Agregar `DependsOn: AttachGateway` |
| Update fails with `No updates` | Template idéntico al actual | Modificar algo en el template para forzar update |

---

## Recursos Adicionales

- [Documentación de CloudFormation](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/Welcome.html)
- [Referencia de tipos de recursos](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-template-resource-type-ref.html)
- [Mejores prácticas para templates](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/best-practices.html)

---

## Limpieza de Recursos

Al finalizar el lab, es importante eliminar los recursos creados para evitar costos innecesarios:

```bash
# Eliminar el stack de CloudFormation
aws cloudformation delete-stack --stack-name mi-vpc-stack

# Esperar a que se complete la eliminación
aws cloudformation wait stack-delete-complete --stack-name mi-vpc-stack

# Verificar que el stack fue eliminado
aws cloudformation describe-stacks --stack-name mi-vpc-stack
# Debe mostrar error porque el stack ya no existe
```

**Nota para el instructor:** Si los estudiantes crearon stacks con nombres diferentes durante la práctica, asegurar que eliminen sus stacks respectivos antes de finalizar.
