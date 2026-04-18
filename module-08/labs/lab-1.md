# Lab 8.1: Configurar VPC Peering entre Múltiples Cuentas

## Objetivo

Implementar conectividad VPC Peering entre cuentas AWS para permitir comunicación privada entre VPCs sin usar internet ni NAT.

## Duración Estimada

45 minutos

## Prerrequisitos

- Dos cuentas AWS (o usar AWS Organizations para demostración)
- Cuenta A con VPC A: `10.0.0.0/16`
- Cuenta B con VPC B: `10.1.0.0/16`
- AWS CLI configurado en ambas cuentas
- Credenciales válidas con permisos EC2 en ambas cuentas
- Security Groups configurados en ambas VPCs

## Recursos Necesarios

| Recurso | Cuenta A | Cuenta B |
|---------|----------|----------|
| VPC | `vpc-a` (10.0.0.0/16) | `vpc-b` (10.1.0.0/16) |
| Subnet pública | `subnet-a-public` | `subnet-b-public` |
| Route Table | `rtb-vpc-a-public` | `rtb-vpc-b-private` |
| Security Group | `sg-vpc-a` | `sg-vpc-b` |
| EC2 Instance | En subnet pública | En subnet privada |

## Diagrama de Arquitectura

```
┌─────────────────────────────────────────────────────────────────────┐
│                        Cuenta A (Requester)                          │
│                                                                      │
│   ┌─────────────────────────────────────────────────────────────┐   │
│   │  VPC A: 10.0.0.0/16                                         │   │
│   │                                                             │   │
│   │   [EC2-A] ──────► Route Table ───► pcx-xxxxxxxx ─────────► │   │
│   │   10.0.0.x        10.1.0.0/16 ──► peering                   │   │
│   └─────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              │ VPC Peering (pcx-xxxxxxxx)
                              │
┌─────────────────────────────────────────────────────────────────────┐
│                        Cuenta B (Accepter)                          │
│                                                                      │
│   ┌─────────────────────────────────────────────────────────────┐   │
│   │  VPC B: 10.1.0.0/16                                         │   │
│   │                                                             │   │
│   │   [EC2-B] ◄────── Route Table ◄────── pcx-xxxxxxxx ◄─────── │   │
│   │   10.1.0.x        10.0.0.0/16 ◄──── peering                 │   │
│   └─────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

## Pasos

### Fase 1: Crear VPC Peering Connection (Cuenta A)

**Paso 1.1: Identificar los IDs necesarios en Cuenta A**

```bash
# Obtener ID de VPC A
aws ec2 describe-vpcs \
    --filters "Name=tag:Name,Values=vpc-a" \
    --query 'Vpcs[0].VpcId' \
    --output text

# Obtener ID de Route Table pública
aws ec2 describe-route-tables \
    --filters "Name=tag:Name,Values=rtb-vpc-a-public" \
    --query 'RouteTables[0].RouteTableId' \
    --output text
```

**Paso 1.2: Obtener el Account ID de Cuenta B**

```bash
# En Cuenta B, obtener el Account ID
aws sts get-caller-identity --query 'Account' --output text
# Resultado: 123456789012
```

**Paso 1.3: Crear VPC Peering Connection**

```bash
# En Cuenta A - Solicitar peering connection
aws ec2 create-vpc-peering-connection \
    --vpc-id vpc-xxxxxxxx \
    --peer-owner-id 123456789012 \
    --peer-vpc-id vpc-yyyyyyyy \
    --tag-specifications 'ResourceType=vpc-peering-connection,Tags=[{Key=Name,Value=peer-across-accounts},{Key=Environment,Value=lab}]'
```

**Paso 1.4: Confirmar el estado del Peering Connection**

```bash
# Verificar que el estado es "pending-acceptance"
aws ec2 describe-vpc-peering-connections \
    --query 'VpcPeeringConnections[0].Status'
```

---

### Fase 2: Aceptar VPC Peering (Cuenta B)

**Paso 2.1: Configurar credenciales de Cuenta B**

```bash
# Configurar perfil para Cuenta B (alternativa: usar role assumption)
aws configure set aws_access_key_id AKIAXXXXX --profile cuenta-b
aws configure set aws_secret_access_key xxxxxxx --profile cuenta-b
```

**Paso 2.2: Aceptar la conexión de peering**

```bash
# En Cuenta B - Aceptar la conexión
aws ec2 accept-vpc-peering-connection \
    --vpc-peering-connection-id pcx-xxxxxxxx
```

**Paso 2.3: Verificar aceptación**

```bash
# Confirmar que el estado cambió a "active"
aws ec2 describe-vpc-peering-connections \
    --vpc-peering-connection-ids pcx-xxxxxxxx \
    --query 'VpcPeeringConnections[0].Status'
```

---

### Fase 3: Configurar Route Tables (Cuenta A)

**Paso 3.1: Actualizar Route Table de VPC A**

```bash
# En Cuenta A - Agregar ruta para VPC B
aws ec2 create-route \
    --route-table-id rtb-xxxxxxxx \
    --destination-cidr-block 10.1.0.0/16 \
    --vpc-peering-connection-id pcx-xxxxxxxx
```

**Paso 3.2: Verificar la ruta creada**

```bash
# Verificar que la ruta existe
aws ec2 describe-route-tables \
    --route-table-id rtb-xxxxxxxx \
    --query 'RouteTables[0].Routes'
```

---

### Fase 4: Configurar Route Tables (Cuenta B)

**Paso 4.1: Actualizar Route Table de VPC B**

```bash
# En Cuenta B - Agregar ruta para VPC A
aws ec2 create-route \
    --route-table-id rtb-yyyyyyyy \
    --destination-cidr-block 10.0.0.0/16 \
    --vpc-peering-connection-id pcx-xxxxxxxx
```

**Paso 4.2: Verificar la ruta creada**

```bash
# Verificar que la ruta existe
aws ec2 describe-route-tables \
    --route-table-id rtb-yyyyyyyy \
    --query 'RouteTables[0].Routes'
```

---

### Fase 5: Actualizar Security Groups

**Paso 5.1: Permitir tráfico desde VPC A en Cuenta B**

```bash
# En Cuenta B - Permitir todo el tráfico desde SG de VPC A (referencia cross-account)
# Para cross-account, se debe usar --ip-permissions con UserIdGroupPairs e indicar el Account ID propietario del SG
aws ec2 authorize-security-group-ingress \
    --group-id sg-yyyyyyyy \
    --ip-permissions '[{"IpProtocol": "-1", "UserIdGroupPairs": [{"GroupId": "sg-xxxxxxxx", "UserId": "111111111111"}]}]'
```

**Paso 5.2: Permitir tráfico inverso desde VPC B en Cuenta A (opcional)**

```bash
# En Cuenta A - Permitir todo el tráfico desde SG de VPC B (referencia cross-account)
aws ec2 authorize-security-group-ingress \
    --group-id sg-xxxxxxxx \
    --ip-permissions '[{"IpProtocol": "-1", "UserIdGroupPairs": [{"GroupId": "sg-yyyyyyyy", "UserId": "222222222222"}]}]'
```

---

### Fase 6: Verificar Conectividad

**Paso 6.1: Lanzar instancias EC2 de prueba**

```bash
# En Cuenta A - Lanzar EC2 en subnet pública
aws ec2 run-instances \
    --image-id $(aws ec2 describe-images --owners amazon --filters 'Name=name,Values=al2023-ami-*-x86_64' --query 'sort_by(Images,&CreationDate)[-1].ImageId' --output text) \
    --instance-type t2.micro \
    --subnet-id subnet-a-public \
    --security-group-ids sg-xxxxxxxx \
    --key-name my-key-pair \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=EC2-VPC-A}]'

# En Cuenta B - Obtener IP privada de EC2 existente
aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=EC2-VPC-B" \
    --query 'Reservations[0].Instances[0].PrivateIpAddress' \
    --output text
```

**Paso 6.2: Probar conectividad**

```bash
# Conectarse a EC2 en Cuenta A vía SSH
ssh -i my-key-pair.pem ec2-user@<EC2-A-IP>

# Desde EC2-A, probar ping a EC2-B (usando IP privada)
ping -c 4 10.1.0.x

# Probar conectividad a servicios AWS (S3, DynamoDB)
aws s3 ls
aws dynamodb list-tables
```

---

## Verificación

Al finalizar el lab, el estudiante debe poder verificar cada uno de los siguientes puntos:

| # | Criterio | Comando de Verificación | Resultado Esperado |
|---|----------|-------------------------|---------------------|
| 1 | VPC Peering Connection está activa | `aws ec2 describe-vpc-peering-connections --query 'VpcPeeringConnections[0].Status'` | `{"Code": "active"}` |
| 2 | Ruta a VPC B existe en RT de VPC A | `aws ec2 describe-route-tables --route-table-id rtb-xxxxxxxx --query 'Routes'` | Incluye destino `10.1.0.0/16` con target `pcx-xxxxxxxx` |
| 3 | Ruta a VPC A existe en RT de VPC B | `aws ec2 describe-route-tables --route-table-id rtb-yyyyyyyy --query 'Routes'` | Incluye destino `10.0.0.0/16` con target `pcx-xxxxxxxx` |
| 4 | Security Groups permiten tráfico | `aws ec2 describe-security-groups --group-ids sg-yyyyyyyy --query 'SecurityGroups[0].IpPermissions'` | Incluye source-group sg-xxxxxxxx |
| 5 | Conectividad ICMP entre VPCs | `ping -c 4 10.1.0.x` desde EC2-A | `4 packets transmitted, 4 received, 0% packet loss` |

---

## Errores Comunes y Soluciones

### Error 1: "Pending Acceptance" indefinitely

**Causa:** La Cuenta B no aceptó la conexión de peering.

**Solución:**
```bash
# Verificar estado actual
aws ec2 describe-vpc-peering-connections \
    --vpc-peering-connection-ids pcx-xxxxxxxx

# Asegurarse de usar credenciales de Cuenta B
export AWS_PROFILE=cuenta-b
aws ec2 accept-vpc-peering-connection \
    --vpc-peering-connection-id pcx-xxxxxxxx
```

### Error 2: "Route not created - conflicting route entry"

**Causa:** Ya existe una ruta que cubre el CIDR destino.

**Solución:**
```bash
# Verificar rutas existentes
aws ec2 describe-route-tables \
    --route-table-id rtb-xxxxxxxx

# Usar replace-route en lugar de create-route si ya existe una ruta
aws ec2 replace-route \
    --route-table-id rtb-xxxxxxxx \
    --destination-cidr-block 10.1.0.0/16 \
    --vpc-peering-connection-id pcx-xxxxxxxx
```

### Error 3: "InvalidGroup.NotFound" al autorizar security group

**Causa:** El Security Group ID no existe o está en otra VPC.

**Solución:**
```bash
# Listar Security Groups en la VPC correcta
aws ec2 describe-security-groups \
    --filters "Name=vpc-id,Values=vpc-yyyyyyyy" \
    --query 'SecurityGroups[*].[GroupId,GroupName]'
```

### Error 4: Conectividad ICMP funciona pero no TCP

**Causa:** Security Group no permite el puerto específico.

**Solución:**
```bash
# Verificar que el Security Group de destino permite el tráfico
aws ec2 describe-security-groups \
    --group-id sg-yyyyyyyy \
    --query 'SecurityGroups[0].IpPermissions'

# Agregar regla para el puerto específico (con referencia cross-account)
aws ec2 authorize-security-group-ingress \
    --group-id sg-yyyyyyyy \
    --ip-permissions '[{"IpProtocol": "tcp", "FromPort": 443, "ToPort": 443, "UserIdGroupPairs": [{"GroupId": "sg-xxxxxxxx", "UserId": "111111111111"}]}]'
```

---

## Limpieza de Recursos

```bash
# En Cuenta A
# Eliminar ruta de peering
aws ec2 delete-route \
    --route-table-id rtb-xxxxxxxx \
    --destination-cidr-block 10.1.0.0/16

# Eliminar conexión de peering
aws ec2 delete-vpc-peering-connection \
    --vpc-peering-connection-id pcx-xxxxxxxx

# En Cuenta B
# Eliminar ruta de peering
aws ec2 delete-route \
    --route-table-id rtb-yyyyyyyy \
    --destination-cidr-block 10.0.0.0/16
```

---

## Referencias

- [VPC Peering Documentation](https://docs.aws.amazon.com/vpc/latest/peering/)
- [AWS CLI VPC Commands](https://docs.aws.amazon.com/cli/latest/reference/ec2/)
