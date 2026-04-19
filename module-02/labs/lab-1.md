# Lab 2.1: Construcción de VPC Básica

## Objetivo

Diseñar y configurar una VPC (Virtual Private Cloud) con subredes públicas y privadas, Internet Gateway, NAT Gateway, Security Groups y Network ACLs (NACLs) que permitan una arquitectura de red segura y funcional en AWS.

---

## Duración Estimada

**110 minutos**

---

## Prerrequisitos

- Cuenta AWS activa con acceso a la consola de AWS
- Permisos IAM para crear VPCs, Subnets, Internet Gateways, NAT Gateways y Security Groups
- Region: **us-east-1** (N. Virginia) recomendada para este laboratorio
- Conocimientos básicos de direccionamiento IP y CIDR

---

## Recursos

- VPC Dashboard en AWS Console
- Maximum VPCs por región: 5 (por defecto)
- Soft limits en NAT Gateways por región

---

## Arquitectura Objetivo

```
┌─────────────────────────────────────────────────────────────┐
│                        VPC (10.0.0.0/16)                    │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐    │
│  │              Subnet Pública (10.0.1.0/24)           │    │
│  │   ┌──────────────┐  ┌─────────────┐                 │    │
│  │   │  EC2 Bastion │  │ Application │                 │    │
│  │   └──────────────┘  └─────────────┘                 │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐    │
│  │              Subnet Privada (10.0.2.0/24)           │    │
│  │   ┌──────────────┐  ┌──────────────┐                │    │
│  │   │  RDS (DB)    │  │  EC2 (App)   │                │    │
│  │   └──────────────┘  └──────────────┘                │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                             │
│  ┌──────────────┐          ┌──────────────┐                 │
│  │ Internet GW  │          │   NAT GW     │                 │
│  └──────────────┘          └──────────────┘                 │
└─────────────────────────────────────────────────────────────┘
```

---

## Pasos

### Paso 1: Crear la VPC

**Tiempo estimado:** 10 minutos

1. Abrir la consola de AWS y navegar a **VPC Dashboard**

2. Seleccionar **Your VPCs** en el menú lateral izquierdo

3. Hacer clic en **Create VPC**

4. Configurar los siguientes parámetros:
   - **Resources to create:** VPC only
   - **Name tag:** `lab02-vpc`
   - **IPv4 CIDR block:** `10.0.0.0/16`
   - **IPv6 CIDR block:** No IPv6 CIDR block (para este lab)
   - **Tenancy:** Default

5. Hacer clic en **Create VPC**

6. **Verificación:** Confirmar que la VPC aparece en la lista con estado `available` y el CIDR `10.0.0.0/16`

---

### Paso 2: Crear las Subnets

**Tiempo estimado:** 15 minutos

#### 2.1 Crear Subnet Pública

1. En el menú lateral de VPC Dashboard, seleccionar **Subnets**

2. Hacer clic en **Create subnet**

3. Configurar la primera subnet:
   - **VPC ID:** Seleccionar `lab02-vpc`
   - **Subnet name:** `lab02-subnet-publica`
   - **Availability Zone:** `us-east-1a` (o la zona disponible)
   - **IPv4 CIDR block:** `10.0.1.0/24`

4. Hacer clic en **Create subnet**

5. **Habilitar auto-assign public IPv4 address:**
   - Seleccionar la subnet recién creada `lab02-subnet-publica`
   - Click en **Actions** > **Edit subnet settings**
   - Activar **Enable auto-assign public IPv4 address**
   - Hacer clic en **Save**

#### 2.2 Crear Subnet Privada

1. Volver a **Create subnet**

2. Configurar la segunda subnet:
   - **VPC ID:** Seleccionar `lab02-vpc`
   - **Subnet name:** `lab02-subnet-privada`
   - **Availability Zone:** `us-east-1a` (misma zona que la pública)
   - **IPv4 CIDR block:** `10.0.2.0/24`

3. Hacer clic en **Create subnet**

**Verificación:** 
- Confirmar que ambas subnets aparecen en la lista
- La subnet pública debe tener `10.0.1.0/24`
- La subnet privada debe tener `10.0.2.0/24`

---

### Paso 3: Crear y Configurar el Internet Gateway

**Tiempo estimado:** 10 minutos

1. En el menú lateral de VPC Dashboard, seleccionar **Internet Gateways**

2. Hacer clic en **Create internet gateway**

3. Configurar:
   - **Name tag:** `lab02-igw`

4. Hacer clic en **Create internet gateway**

5. **Adjuntar el Internet Gateway a la VPC:**
   - Seleccionar el IGW recién creado
   - Click en **Actions** > **Attach to VPC**
   - Seleccionar la VPC `lab02-vpc`
   - Hacer clic en **Attach internet gateway**

**Verificación:** El estado del Internet Gateway debe cambiar a `attached` y mostrar el VPC ID de `lab02-vpc`.

---

### Paso 4: Crear el NAT Gateway

**Tiempo estimado:** 15 minutos

1. En el menú lateral de VPC Dashboard, seleccionar **NAT Gateways**

2. Hacer clic en **Create NAT gateway**

3. Configurar:
   - **Name:** `lab02-natgw`
   - **Subnet:** Seleccionar `lab02-subnet-publica` (debe estar en subnet pública)
   - **Connectivity type:** Public
   - **Elastic IP allocation ID:** Hacer clic en **Allocate Elastic IP**

4. Hacer clic en **Create NAT gateway**

5. **Esperar disponibilidad:** El NAT Gateway puede tomar 1-2 minutos en cambiar a estado `available`. Refrescar la página periódicamente.

**Verificación:** El NAT Gateway debe mostrar estado `available` con la Elastic IP asignada.

---

### Paso 5: Configurar las Route Tables

**Tiempo estimado:** 15 minutos

#### 5.1 Crear Route Table para Subnet Pública

1. En el menú lateral de VPC Dashboard, seleccionar **Route Tables**

2. Hacer clic en **Create route table**

3. Configurar:
   - **Name:** `lab02-rt-publica`
   - **VPC:** Seleccionar `lab02-vpc`

4. Hacer clic en **Create route table**

5. **Agregar ruta para acceso a Internet:**
   - Seleccionar la route table `lab02-rt-publica`
   - Ir a la pestaña **Routes** y hacer clic en **Edit routes**
   - Hacer clic en **Add route**
   - Configurar:
     - **Destination:** `0.0.0.0/0`
     - **Target:** Seleccionar **Internet Gateway** > `lab02-igw`
   - Hacer clic en **Save routes**

6. **Asociar con subnet pública:**
   - Ir a la pestaña **Subnet associations**
   - Hacer clic en **Edit subnet associations**
   - Seleccionar `lab02-subnet-publica`
   - Hacer clic en **Save associations**

#### 5.2 Crear Route Table para Subnet Privada

1. Volver a **Create route table**

2. Configurar:
   - **Name:** `lab02-rt-privada`
   - **VPC:** Seleccionar `lab02-vpc`

3. Hacer clic en **Create route table**

4. **Agregar ruta para NAT Gateway:**
   - Seleccionar la route table `lab02-rt-privada`
   - Ir a la pestaña **Routes** y hacer clic en **Edit routes**
   - Hacer clic en **Add route**
   - Configurar:
     - **Destination:** `0.0.0.0/0`
     - **Target:** Seleccionar **NAT Gateway** > `lab02-natgw`
   - Hacer clic en **Save routes**

7. **Asociar con subnet privada:**
   - Ir a la pestaña **Subnet associations**
   - Hacer clic en **Edit subnet associations**
   - Seleccionar `lab02-subnet-privada`
   - Hacer clic en **Save associations**

**Verificación:**
- `lab02-rt-publica` debe tener ruta a `0.0.0.0/0` → IGW y estar asociada a `lab02-subnet-publica`
- `lab02-rt-privada` debe tener ruta a `0.0.0.0/0` → NAT GW y estar asociada a `lab02-subnet-privada`

---

### Paso 6: Crear los Security Groups

**Tiempo estimado:** 15 minutos

#### 6.1 Security Group para Bastion Host (Subnet Pública)

1. En el menú lateral de VPC Dashboard, seleccionar **Security Groups**

2. Hacer clic en **Create security group**

3. Configurar información básica:
   - **Security group name:** `lab02-sg-bastion`
   - **Description:** Security group para bastion host
   - **VPC:** Seleccionar `lab02-vpc`

4. **Agregar reglas de entrada (Inbound rules):**
   - Hacer clic en **Edit inbound rules**
   - Hacer clic en **Add rule**
   - Configurar:
     - **Type:** SSH (22)
     - **Source type:** Anywhere-IPv4 (`0.0.0.0/0`)
   - Hacer clic en **Save rules**

5. **Verificar reglas de salida (Outbound rules):**
   - Por defecto, todo el tráfico saliente está permitido (Stateful)

6. Hacer clic en **Create security group**

#### 6.2 Security Group para Instancias Privadas

1. Volver a **Create security group**

2. Configurar:
   - **Security group name:** `lab02-sg-privada`
   - **Description:** Security group para instancias en subnet privada
   - **VPC:** Seleccionar `lab02-vpc`

3. **Agregar reglas de entrada:**
   - **Regla 1 - SSH desde Bastion:**
     - Type: SSH (22)
     - Source: Custom → Buscar `lab02-sg-bastion`
   - **Regla 2 - HTTP desde cualquier lugar (para testing):**
     - Type: HTTP (80)
     - Source: Anywhere-IPv4 (`0.0.0.0/0`)
   
4. Hacer clic en **Create security group**

**Verificación:**
- `lab02-sg-bastion` debe permitir SSH desde `0.0.0.0/0`
- `lab02-sg-privada` debe permitir SSH solo desde el SG del bastion

---

### Paso 6.5: Crear Network ACLs (NACLs)

**Tiempo estimado:** 15 minutos

Las Network ACLs (NACLs) son una capa de seguridad adicional que opera a nivel de subnet. A diferencia de los Security Groups (stateful), los NACLs son **stateless**, lo que significa que debes permitir explícitamente tanto el tráfico de entrada como el de salida para las respuestas.

#### 6.5.1 Conceptos Fundamentales

| Característica | Security Group | NACL |
|----------------|----------------|------|
| **Estado** | Stateful (respuesta automática) | Stateless (requiere regla explícita) |
| **Alcance** | Instancia | Subnet |
| **Reglas** | Solo permit | Permit y Deny |
| **Evaluación** | Todas las reglas se evaluan | En orden numérico, primera coincidencia |
| **Default** | Deny all (sin reglas) | Allow all (nuevos NACLs) |

#### 6.5.2 Crear NACL para Subnet Privada

1. En el menú lateral de VPC Dashboard, seleccionar **Network ACLs**

2. Hacer clic en **Create network ACL**

3. Configurar:
   - **Name tag:** `lab02-nacl-privada`
   - **VPC:** Seleccionar `lab02-vpc`

4. Hacer clic en **Create network ACL**

#### 6.5.3 Asociar NACL a la Subnet Privada

1. Seleccionar el NACL recién creado `lab02-nacl-privada`

2. Ir a la pestaña **Subnet associations**

3. Hacer clic en **Edit subnet associations**

4. Seleccionar `lab02-subnet-privada`

5. Hacer clic en **Save associations**

**Verificación:** La subnet `lab02-subnet-privada` aparece asociada al NACL `lab02-nacl-privada`

#### 6.5.4 Configurar Reglas de Entrada

1. Con el NACL `lab02-nacl-privada` seleccionado, ir a la pestaña **Inbound rules**

2. Hacer clic en **Edit inbound rules**

3. **Agregar regla para SSH (respuesta):**
   - **Rule number:** `100`
   - **Type:** Custom TCP
   - **Protocol:** TCP (6)
   - **Port range:** `1024-65535` (puertos efímeros)
   - **Source:** `0.0.0.0/0`
   - **Allow/Deny:** Allow

4. **Agregar regla para HTTP (respuesta):**
   - **Rule number:** `110`
   - **Type:** Custom TCP
   - **Protocol:** TCP
   - **Port range:** `1024-65535`
   - **Source:** `0.0.0.0/0`
   - **Allow/Deny:** Allow

5. **Agregar regla para HTTPS (respuesta):**
   - **Rule number:** `120`
   - **Type:** Custom TCP
   - **Protocol:** TCP
   - **Port range:** `1024-65535`
   - **Source:** `0.0.0.0/0`
   - **Allow/Deny:** Allow

6. Hacer clic en **Save changes**

#### 6.5.5 Configurar Reglas de Salida

1. Ir a la pestaña **Outbound rules**

2. Hacer clic en **Edit outbound rules**

3. **Agregar regla para todo el tráfico saliente:**
   - **Rule number:** `100`
   - **Type:** All Traffic
   - **Protocol:** All
   - **Port range:** All
   - **Destination:** `0.0.0.0/0`
   - **Allow/Deny:** Allow

4. Hacer clic en **Save changes**

**Nota importante:** Los NACLs evaluados en orden numérico. Las reglas con números menores se evalúan primero. El número 100 se evalúa antes que el 110 o 120.

#### 6.5.6 Comparar Comportamiento: Security Groups vs NACLs

Para demostrar la diferencia entre stateful (SG) y stateless (NACL):

1. **Security Group (Stateful):**
   - Si permites SSH entrante desde `0.0.0.0/0`, la respuesta automática está permitida sin regla adicional
   - El return traffic es permitido automáticamente por el estado de la conexión

2. **NACL (Stateless):**
   - Debes permitir explícitamente el tráfico de respuesta
   - SSH usa puertos efímeros (1024-65535) para la respuesta
   - Sin la regla de entrada para puertos efémeros, la respuesta sería denegada

**Prueba de conectividad:**
- Verificar que las instancias en la subnet privada pueden acceder a Internet vía NAT Gateway
- El NAT Gateway ya tiene sus propias reglas de SG que permiten el tráfico

**Verificación:**
- `lab02-nacl-privada` está asociada a `lab02-subnet-privada`
- Las reglas de entrada permiten puertos efímeros desde `0.0.0.0/0`
- Las reglas de salida permiten todo el tráfico saliente

---

### Paso 7: Verificación de la Arquitectura

**Tiempo estimado:** 10 minutos

Para validar que la arquitectura funciona correctamente, se pueden lanzar instancias EC2 de prueba:

#### 7.1 Lanzar Instancia de Prueba en Subnet Pública

1. Navegar a **EC2 Dashboard** > **Instances**

2. Hacer clic en **Launch instances**

3. Configurar:
   - **Name:** `lab02-bastion-test`
   - **AMI:** Amazon Linux 2 (Free tier eligible)
   - **Instance type:** `t3.micro`
   - **Key pair:** Crear un key pair nuevo o usar uno existente
   - **Network settings:**
     - VPC: `lab02-vpc`
     - Subnet: `lab02-subnet-publica`
     - Auto-assign public IP: Enable
     - Security group: `lab02-sg-bastion`

4. **Configurar acceso por contraseña:**
   - Expandir **Advanced details**
   - En **User data**, agregar el siguiente script:
     ```bash
     #!/bin/bash
     # Habilitar autenticación por contraseña para ec2-user
     echo "ec2-user:LabPassword123" | chpasswd
     sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
     sed -i 's/#PasswordAuthentication/PasswordAuthentication/' /etc/ssh/sshd_config
     systemctl restart sshd
     ```

5. Hacer clic en **Launch instance**

**Nota:** La contraseña `LabPassword123` se puede cambiar posteriormente con el comando `sudo passwd ec2-user`.

#### 7.2 Lanzar Instancia de Prueba en Subnet Privada

1. Volver a **Launch instances**

2. Configurar:
   - **Name:** `lab02-app-test`
   - **AMI:** Amazon Linux 2 (Free tier eligible)
   - **Instance type:** `t3.micro`
   - **Key pair:** Mismo key pair
   - **Network settings:**
     - VPC: `lab02-vpc`
     - Subnet: `lab02-subnet-privada`
     - Auto-assign public IP: Disable
     - Security group: `lab02-sg-privada`

3. **Configurar acceso por contraseña:**
   - Expandir **Advanced details**
   - En **User data**, agregar el mismo script:
     ```bash
     #!/bin/bash
     # Habilitar autenticación por contraseña para ec2-user
     echo "ec2-user:LabPassword123" | chpasswd
     sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
     sed -i 's/#PasswordAuthentication/PasswordAuthentication/' /etc/ssh/sshd_config
     systemctl restart sshd
     ```

4. Hacer clic en **Launch instance**

**Nota:** La contraseña es la misma para ambas instancias: `LabPassword123`

#### 7.3 Pruebas de Conectividad

**Credenciales de acceso:**
- **Usuario:** `ec2-user`
- **Contraseña:** `LabPassword123`

1. **Desde Internet a Bastion (debe funcionar):**
   - Obtener la IP pública del bastion
   - Conectar via SSH usando contraseña:
     ```bash
     ssh ec2-user@<ip-publica>
     # Ingresar contraseña: LabPassword123
     ```
   - Alternativamente, usar key pair: `ssh -i "mi-keypair.pem" ec2-user@<ip-publica>`

2. **Desde Bastion a Instancia Privada (debe funcionar):**
   - Desde la sesión SSH del bastion, hacer ping a la IP privada de la instancia privada
   - Probar SSH a la instancia privada usando su IP privada:
     ```bash
     ssh ec2-user@<ip-privada>
     # Ingresar contraseña: LabPassword123
     ```

3. **Desde Instancia Privada a Internet (debe funcionar vía NAT):**
   - Conectar primero al bastion
   - Desde bastion, SSH a la instancia privada
   - Desde la instancia privada, verificar acceso a Internet: `curl www.google.com`

4. **Desde Internet a Instancia Privada (debe fallar):**
   - Intentar conexión directa a la IP pública de la instancia privada (no tiene)
   - Intentar SSH directamente a la instancia privada (debe estar bloqueado por SG)

---

## Criterios de Verificación

Al completar este laboratorio, el estudiante debe ser capaz de:

- [ ] Crear una VPC con bloque CIDR IPv4 apropiado (`10.0.0.0/16`)
- [ ] Crear dos subnets (una pública y una privada) con CIDRs distintos (`10.0.1.0/24` y `10.0.2.0/24`)
- [ ] Habilitar auto-assign de IP pública en la subnet pública
- [ ] Crear y adjuntar un Internet Gateway a la VPC
- [ ] Crear un NAT Gateway en la subnet pública
- [ ] Configurar Route Table pública con ruta al Internet Gateway (`0.0.0.0/0` → IGW)
- [ ] Configurar Route Table privada con ruta al NAT Gateway (`0.0.0.0/0` → NAT GW)
- [ ] Asociar correctamente cada Route Table a su subnet correspondiente
- [ ] Crear Security Group para bastion con SSH permitido desde cualquier lugar
- [ ] Crear Security Group para instancias privadas que permita SSH solo desde el SG del bastion
- [ ] Crear un Network ACL (NACL) y asociarlo a la subnet privada
- [ ] Configurar reglas de entrada en NACL para puertos efímeros (stateless)
- [ ] Configurar reglas de salida en NACL para permitir tráfico saliente
- [ ] Explicar la diferencia entre Security Groups (stateful) y NACLs (stateless)
- [ ] Verificar que instancias en subnet pública tienen conectividad a Internet
- [ ] Verificar que instancias en subnet privada acceden a Internet vía NAT Gateway
- [ ] Verificar que instancia privada no es accesible directamente desde Internet

---

## Limpieza de Recursos

** IMPORTANTE:** Al finalizar el laboratorio, eliminar los recursos creados para evitar costos:

1. **Terminar instancias EC2:**
   - EC2 Dashboard > Instances > Select instances > Instance state > Terminate instance

2. **Eliminar NAT Gateway:**
   - VPC Dashboard > NAT Gateways > Select > Actions > Delete NAT gateway

3. **Eliminar Elastic IP (si se liberó con el NAT):**
   - VPC Dashboard > Elastic IPs > Select > Actions > Release Elastic IP addresses

4. **Eliminar Route Tables:**
   - VPC Dashboard > Route Tables > Select RT > Actions > Delete route table
   - Eliminar primero las asociaciones

5. **Desadjuntar y eliminar Internet Gateway:**
   - VPC Dashboard > Internet Gateways > Select IGW > Actions > Detach from VPC
   - Luego Actions > Delete internet gateway

6. **Eliminar Security Groups:**
   - VPC Dashboard > Security Groups > Select SG > Actions > Delete security groups

7. **Eliminar Network ACLs:**
   - VPC Dashboard > Network ACLs > Select NACL > Actions > Delete network ACL
   - Primero desasociar las subnets si están asociadas

8. **Eliminar Subnets:**
   - VPC Dashboard > Subnets > Select subnet > Actions > Delete subnet

9. **Eliminar VPC:**
   - VPC Dashboard > Your VPCs > Select VPC > Actions > Delete VPC

---

## Errores Comunes y Soluciones

| Error | Causa | Solución |
|-------|-------|----------|
| `CIDR conflict` al crear VPC | Ya existe una VPC con CIDR que se solapa | Usar un bloque CIDR diferente (ej: `10.1.0.0/16`) |
| NAT Gateway atascado en `pending` | Elastic IP no se asignó correctamente | Eliminar y recrear, asegurar que la subnet es pública |
| `RouteNotGlable` al probar conectividad | Ruta no configurada correctamente | Verificar que la ruta `0.0.0.0/0` apunta al target correcto |
| No se puede hacer SSH al bastion | Security Group no permite puerto 22 | Verificar regla de entrada en SG del bastion |
| Instancia privada no tiene Internet | Route Table mal asociada o sin NAT | Verificar RT de subnet privada tiene ruta a NAT GW |
| `Internet Gateway not attached` | IGW no está adjuntado a la VPC | Seleccionar IGW > Actions > Attach to VPC |

---

## Referencias

- [Amazon VPC Documentation](https://docs.aws.amazon.com/vpc/latest/userguide/)
- [VPC CIDR Blocks](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-cidr-blocks.html)
- [Internet Gateways](https://docs.aws.amazon.com/vpc/latest/userguide/VPC_Internet_Gateway.html)
- [NAT Gateways](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-nat.html)
- [Security Groups](https://docs.aws.amazon.com/vpc/latest/userguide/security-groups.html)
