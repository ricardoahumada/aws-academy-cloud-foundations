# Lab 2.5: VPC Peering - Conexión entre VPCs de Diferentes Cuentas (OPCIONAL)

## Objetivo

Establecer una conexión de VPC Peering entre dos VPCs creadas por diferentes estudiantes o grupos en la misma región, permitiendo comunicación directa entre instancias sin necesidad de Internet ni NAT Gateway.

---

## Duración Estimada

**60 minutos**

---

## Prerrequisitos

- Lab 2.1 completado (conceptos básicos de VPC, subnets, route tables, security groups)
- Dos cuentas AWS o dos estudiantes con cuenta propia
- Key pair creado para acceso SSH

---

## Arquitectura Objetivo

```
┌─────────────────────────────────────────────────────────────────────┐
│                    Cuenta Alumno A (us-east-1)                       │
│                                                                      │
│  VPC A: 10.1.0.0/16                                                  │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │ Subnet Pública: 10.1.1.0/24                                  │    │
│  │   ┌──────────────┐                                           │    │
│  │   │ EC2 Server   │◄──── HTTP, SSH desde Alumno B             │    │
│  │   │ (Alumno A)   │                                           │    │
│  │   └──────────────┘                                           │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                                                                      │
│  Route Table: 10.2.0.0/16 ──────────────► pcx-XXXXXXXX (Peering)    │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              │ VPC Peering Connection
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    Cuenta Alumno B (us-east-1)                       │
│                                                                      │
│  VPC B: 10.2.0.0/16                                                  │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │ Subnet Pública: 10.2.1.0/24                                  │    │
│  │   ┌──────────────┐                                           │    │
│  │   │ EC2 Client   │────► curl http://10.1.1.x/index.html    │    │
│  │   │ (Alumno B)   │                                           │    │
│  │   └──────────────┘                                           │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                                                                      │
│  Route Table: 10.1.0.0/16 ──────────────► pcx-XXXXXXXX (Peering)    │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Notas Importantes

### Limitaciones de VPC Peering

| Característica | Detalle |
|----------------|---------|
| **Transitivo** | NO hay routing transitivo. Si A↔B y B↔C, A no puede comunicarse con C |
| **Solapamiento de CIDRs** | Los bloques CIDR NO pueden solaparse |
| **Cross-region** | Sí es posible, pero latency y costo aumentan |

### CIDRs para el Lab

| Participante | VPC CIDR | Subnet |
|--------------|----------|--------|
| Alumno A | `10.1.0.0/16` | `10.1.1.0/24` |
| Alumno B | `10.2.0.0/16` | `10.2.1.0/24` |

---

## Pasos

### Paso 1: Configurar VPC y Recursos - Alumno A

**Tiempo estimado:** 15 minutos

#### 1.1 Crear VPC

1. En AWS Console (Cuenta Alumno A), navegar a **VPC Dashboard**

2. Hacer clic en **Create VPC**

3. Configurar:
   - **Name tag:** `lab25-vpc-alumnoa`
   - **IPv4 CIDR block:** `10.1.0.0/16`

4. Hacer clic en **Create VPC**

#### 1.2 Crear Subnet

1. Seleccionar **Subnets** > **Create subnet**

2. Configurar:
   - **VPC ID:** `lab25-vpc-alumnoa`
   - **Subnet name:** `lab25-subnet-alumnoa`
   - **Availability Zone:** `us-east-1a`
   - **IPv4 CIDR block:** `10.1.1.0/24`

3. **Habilitar auto-assign public IPv4:**
   - Seleccionar la subnet > **Actions** > **Edit subnet settings**
   - Activar **Enable auto-assign public IPv4 address**

#### 1.3 Crear y Adjuntar Internet Gateway

1. **Create internet gateway** con nombre `lab25-igw-alumnoa`

2. Seleccionar el IGW > **Actions** > **Attach to VPC** > `lab25-vpc-alumnoa`

#### 1.4 Crear Route Table

1. Crear route table `lab25-rt-alumnoa` para `lab25-vpc-alumnoa`

2. **Agregar ruta a Internet:**
   - Edit routes > Add route:
     - **Destination:** `0.0.0.0/0`
     - **Target:** Internet Gateway > `lab25-igw-alumnoa`

3. **Asociar subnet:**
   - Subnet associations > Edit > seleccionar `lab25-subnet-alumnoa`

#### 1.5 Crear Security Group

1. Crear security group `lab25-sg-alumnoa` para `lab25-vpc-alumnoa`

2. **Reglas de entrada:**
   - **SSH (22):** Anywhere-IPv4 (`0.0.0.0/0`)
   - **HTTP (80):** Anywhere-IPv4 (`0.0.0.0/0`)
   - **ICMP (Ping):** Custom → `10.2.0.0/16`

#### 1.6 Lanzar Instancia Servidor

1. **EC2 Dashboard** > **Launch instances**

2. Configurar:
   - **Name:** `lab25-server-alumnoa`
   - **AMI:** Amazon Linux 2 (Free tier)
   - **Instance type:** `t3.micro`
   - **Key pair:** `lab02-keypair`
   - **Network:** `lab25-vpc-alumnoa`, subnet `lab25-subnet-alumnoa`
   - **Auto-assign public IP:** Enable
   - **Security group:** `lab25-sg-alumnoa`

3. **User data** para Apache:
   ```bash
   #!/bin/bash
   yum update -y
   yum install -y httpd
   systemctl start httpd
   systemctl enable httpd
   echo "<h1>Servidor Alumno A - VPC Peering Lab</h1>" > /var/www/html/index.html
   echo "<p>IP Privada: $(hostname -I | awk '{print $1}')</p>" >> /var/www/html/index.html
   ```

4. Hacer clic en **Launch instance**

5. **Registrar IPs:**
   - **IPv4 pública:** `____________`
   - **IPv4 privada:** `____________`

---

### Paso 2: Configurar VPC y Recursos - Alumno B

**Tiempo estimado:** 15 minutos

#### 2.1 Crear VPC

- **Name:** `lab25-vpc-alumnob`
- **CIDR:** `10.2.0.0/16`

#### 2.2 Crear Subnet

- **Name:** `lab25-subnet-alumnob`
- **CIDR:** `10.2.1.0/24`
- Habilitar auto-assign public IPv4

#### 2.3 Internet Gateway

- **Name:** `lab25-igw-alumnob`
- Adjuntar a `lab25-vpc-alumnob`

#### 2.4 Route Table

- **Name:** `lab25-rt-alumnob`
- Ruta `0.0.0.0/0` → IGW
- Asociar subnet `lab25-subnet-alumnob`

#### 2.5 Security Group

- **Name:** `lab25-sg-alumnob`
- **Reglas de entrada:**
  - **SSH (22):** Anywhere-IPv4 (`0.0.0.0/0`)
  - **ICMP (Ping):** Custom → `10.1.0.0/16`

#### 2.6 Lanzar Instancia Cliente

- **Name:** `lab25-client-alumnob`
- AMI: Amazon Linux 2, `t3.micro`
- VPC: `lab25-vpc-alumnob`, subnet `lab25-subnet-alumnob`
- Security group: `lab25-sg-alumnob`

---

### Paso 3: Crear VPC Peering Connection

**Tiempo estimado:** 10 minutos

#### 3.1 Intercambio de Información

**Alumno A comparte con Alumno B:**
- AWS Account ID de su cuenta
- VPC ID: `lab25-vpc-alumnoa` (ej: `vpc-xxxxxxxx`)

**Alumno B comparte con Alumno A:**
- AWS Account ID de su cuenta
- VPC ID: `lab25-vpc-alumnob`

#### 3.2 Crear Request de Peering (Alumno A)

1. **VPC Dashboard** > **Peering Connections** > **Create peering connection**

2. Configurar:
   - **Name:** `lab25-peering-ab`
   - **VPC ID (Requester):** `lab25-vpc-alumnoa`
   - **Account:** Another account
   - **Account ID:** `ACCOUNT_ID_ALUMNO_B`
   - **Region:** This region

3. Hacer clic en **Create peering connection**

4. **Registrar Peering Connection ID:** `pcx-____________`

#### 3.3 Aceptar Request (Alumno B)

1. En **Peering Connections** de Alumno B, aparece `pending-acceptance`

2. Seleccionar > **Actions** > **Accept request**

3. Estado cambia a `active`

---

### Paso 4: Configurar Route Tables

**Tiempo estimado:** 10 minutos

#### 4.1 Alumno A

1. **Route Tables** > seleccionar `lab25-rt-alumnoa`

2. **Routes** > **Edit routes** > **Add route**:
   - **Destination:** `10.2.0.0/16`
   - **Target:** Peering Connection > `lab25-peering-ab`

3. Guardar

#### 4.2 Alumno B

1. **Route Tables** > seleccionar `lab25-rt-alumnob`

2. **Add route**:
   - **Destination:** `10.1.0.0/16`
   - **Target:** Peering Connection > `lab25-peering-ab`

3. Guardar

---

### Paso 5: Actualizar Security Groups

**Tiempo estimado:** 5 minutos

#### 5.1 Alumno A

Editar `lab25-sg-alumnoa` - Agregar reglas de entrada:
- **SSH (22):** Custom → `10.2.0.0/16`
- **HTTP (80):** Custom → `10.2.0.0/16`

#### 5.2 Alumno B

Editar `lab25-sg-alumnob` - Agregar reglas de entrada:
- **SSH (22):** Custom → `10.1.0.0/16`
- **HTTP (80):** Custom → `10.1.0.0/16`

---

### Paso 6: Verificación de Conectividad

**Tiempo estimado:** 10 minutos

#### 6.1 Desde Alumno B hacia Alumno A

Conectar a `lab25-client-alumnob` por SSH:

```bash
ssh ec2-user@<ip-publica-alumnob>
```

**Probar ping:**
```bash
ping -c 3 10.1.1.100
```

**Probar HTTP:**
```bash
curl http://10.1.1.100
```

#### 6.2 Desde Alumno A hacia Alumno B

```bash
ping -c 3 10.2.1.100
```

---

## Criterios de Verificación

- [ ] VPC con CIDR único creada (no solapado)
- [ ] Instancia Servidor con Apache funcionando
- [ ] VPC Peering connection estado `active`
- [ ] Route tables configuradas en ambas cuentas
- [ ] Security Groups permiten tráfico cross-VPC
- [ ] Ping funciona entre VPCs
- [ ] HTTP funciona entre VPCs

---

## Limpieza de Recursos

** IMPORTANTE:** Al finalizar, cada alumno elimina sus recursos:

### Alumno A:
1. Terminar instancia `lab25-server-alumnoa`
2. Eliminar Security Group `lab25-sg-alumnoa`
3. Eliminar Route Table `lab25-rt-alumnoa`
4. Desadjuntar y eliminar Internet Gateway `lab25-igw-alumnoa`
5. Eliminar Subnet `lab25-subnet-alumnoa`
6. Eliminar VPC `lab25-vpc-alumnoa`

### Alumno B:
7. Mismos pasos para sus recursos

### Eliminar Peering:
8. **Peering Connections** > seleccionar `lab25-peering-ab` > **Delete**

---

## Errores Comunes y Soluciones

| Error | Causa | Solución |
|-------|-------|----------|
| `pending-acceptance` | Peering no aceptado | Alumno B debe aceptar el request |
| Timeout en ping | Ruta o SG no configurados | Verificar route tables y reglas ICMP |
| `Connection refused` HTTP | Apache no corriendo | Verificar httpd con `systemctl status httpd` |
| CIDRs se solapan | Error en configuración | Usar 10.1.x.x y 10.2.x.x |

---

## Referencias

- [VPC Peering Documentation](https://docs.aws.amazon.com/vpc/latest/peering/)
- [VPC Peering Basics](https://docs.aws.amazon.com/vpc/latest/peering/what-is-vpc-peering.html)
