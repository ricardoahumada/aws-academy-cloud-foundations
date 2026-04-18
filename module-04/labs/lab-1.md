# Lab 4.1: Arquitectura Web de 3 Capas con Alta Disponibilidad

## Objetivo

Implementar una arquitectura web de 3 capas (presentación, aplicación, datos) con alta disponibilidad utilizando:
- Application Load Balancer (ALB)
- Auto Scaling Groups (ASG)
- Amazon RDS con Multi-AZ

Al finalizar, comprenderás cómo diseñar y desplegar arquitecturas escalables y tolerantes a fallos en AWS.

## Duración estimada

90 minutos

## Prerrequisitos

- VPC con subnets en al menos 3 Availability Zones (configuradas en el módulo anterior)
- Security Groups ya creados para las capas web, aplicación y base de datos
- Key pair para instancias EC2
- Cuenta AWS con permisos para EC2, RDS, ELB, Auto Scaling

## Arquitectura objetivo

```
                    ┌─────────────────────────────┐
                    │        Internet              │
                    └──────────────┬──────────────┘
                                   │
                          ┌────────▼────────┐
                          │       ALB        │
                          │  (Multi-AZ)     │
                          └────────┬────────┘
                                   │
        ┌──────────────────────────┼──────────────────────────┐
        │                          │                          │
   ┌────▼────┐               ┌────▼────┐               ┌────▼────┐
   │ AZ-1    │               │ AZ-2    │               │ AZ-3    │
   │ Web     │               │ Web     │               │ Web     │
   │ Tier    │               │ Tier    │               │ Tier    │
   │ (ASG)   │               │ (ASG)   │               │ (ASG)   │
   └─────────┘               └─────────┘               └─────────┘
        │                          │                          │
   ┌────▼────┐               ┌────▼────┐               ┌────▼────┐
   │ AZ-1    │               │ AZ-2    │               │ AZ-3    │
   │ App     │               │ App     │               │ App     │
   │ Tier    │               │ Tier    │               │ Tier    │
   └─────────┘               └─────────┘               └─────────┘
        │                          │                          │
                    ┌──────────────┴──────────────┐
                    │                             │
             ┌──────▼──────┐              ┌──────▼──────┐
             │  Primary    │ ───Sync────▶ │   Standby   │
             │  RDS        │              │   RDS       │
             │  (AZ-1)     │              │  (AZ-2)     │
             └─────────────┘              └─────────────┘
```

---

## Paso 1: Crear Application Load Balancer

### 1.1 Acceder a la consola de EC2

1. En la consola de AWS, ir a **Services** > **EC2**
2. En el panel izquierdo, seleccionar **Load Balancers** bajo la sección **LOAD BALANCING**

### 1.2 Crear el ALB

1. Hacer clic en **Create Load Balancer**
2. Seleccionar **Application Load Balancer** > **Create**
3. Configurar la sección **Basic Configuration**:
   - **Name**: `mi-alb-web`
   - **Scheme**: `Internet-facing`
   - **IP address type**: `IPv4`
4. En **Network Mapping**:
   - **VPC**: seleccionar `mi-vpc`
   - **Mappings**: seleccionar las 3 subnets públicas (una por AZ)
5. En **Security Groups**:
   - Seleccionar `sg-web` (debe permitir HTTP en puerto 80 y HTTPS en 443)
6. En **Listeners and Routing**:
   - Protocol: `HTTP`, Port: `80`
   - Default action: **Forward to** > **Target group** > **New target group**
7. Crear el target group `tg-web-servers`:
   - **Target type**: Instances
   - **Protocol**: HTTP
   - **Port**: 80
   - **Health check path**: `/index.html`
   - **Healthy threshold**: 2
   - **Unhealthy threshold**: 3
   - **Timeout**: 5 seconds
   - **Interval**: 30 seconds
8. Dejar el target group vacío (el ASG lo registrará después)
9. Clic en **Create**

### 1.3 Verificar creación del ALB

1. En la lista de Load Balancers, localizar `mi-alb-web`
2. Copiar el **DNS name** (será necesario más adelante)
3. Verificar que el estado sea `active`

---

## Paso 2: Crear Launch Template para Web Tier

### 2.1 Acceder a Launch Templates

1. En la consola EC2, seleccionar **Launch Templates** en la sección **INSTANCES**
2. Clic en **Create launch template**

### 2.2 Configurar el Launch Template

1. **Launch template name and description**:
   - **Template name**: `lt-web-tier`
   - **Template version description**: `Web tier launch template v1`

2. **Amazon Machine Image (AMI)**:
   - Usar **Amazon Linux 2023** (seleccionar desde el AMI Catalog en la consola; buscar "Amazon Linux 2023" y elegir la versión más reciente para x86_64)

3. **Instance type**:
   - **Instance type**: `t3.micro`

4. **Key pair**:
   - Seleccionar `mi-keypair`

5. **Network settings**:
   - **Subnet**: No subnet (requerido para ASG con múltiples AZs)
   - **Security groups**: seleccionar `sg-web`
   - **Auto-assign public IP**: Enable

6. **Storage (volumes)**:
   - Dejar configuración por defecto (Root volume)

7. **User data** (copy and paste):

> **Nota:** Amazon Linux 2023 usa `dnf` como gestor de paquetes. Los metadatos de instancia requieren IMDSv2 (token previo).

```bash
#!/bin/bash
dnf update -y
dnf install -y httpd
systemctl start httpd
systemctl enable httpd

# Obtener metadatos via IMDSv2
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/instance-id)
AZ=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/placement/availability-zone)
LOCAL_IP=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/local-ipv4)

cat > /var/www/html/index.html << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Web Server - AZ Info</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .info { background: #e3f2fd; padding: 20px; border-radius: 8px; }
    </style>
</head>
<body>
    <div class="info">
        <h1>Web Server Running</h1>
        <p><strong>Instance ID:</strong> ${INSTANCE_ID}</p>
        <p><strong>Availability Zone:</strong> ${AZ}</p>
        <p><strong>Local IP:</strong> ${LOCAL_IP}</p>
    </div>
</body>
</html>
EOF
```

8. Clic en **Create launch template**

---

## Paso 3: Crear Auto Scaling Group para Web Tier

### 3.1 Crear el ASG

1. En la consola EC2, seleccionar **Auto Scaling Groups** en la sección **AUTO SCALING**
2. Clic en **Create Auto Scaling Group**

### 3.2 Configurar el ASG

1. **Choose launch template or configuration**:
   - Seleccionar **Launch template**: `lt-web-tier`
   - Clic en **Next**

2. **Configure settings**:
   - **Auto Scaling group name**: `asg-web-tier`
   - Clic en **Next**

3. **Network**:
   - **VPC**: `mi-vpc`
   - **Availability Zones and subnets**: seleccionar las 3 subnets públicas

4. **Load balancing**:
   - Marcar **Attach to an existing load balancer**
   - **Existing target groups**: seleccionar `tg-web-servers`
   - Marcar **Enable group metrics collection within CloudWatch**

5. **Health checks**:
   - **Health check type**: `ELB`
   - **Health check grace period**: `60` seconds

6. **Configuring group size**:
   - **Desired capacity**: `2`
   - **Minimum capacity**: `2`
   - **Maximum capacity**: `4`

7. **Scaling policies**:
   - Seleccionar **Target tracking scaling policy**
   - **Scaling policy name**: `cpu-target-tracking`
   - **Metric type**: `Average CPU utilization`
   - **Target value**: `70`
   - Clic en **Next** > **Next** > **Create Auto Scaling Group**

### 3.3 Verificar que las instancias se registren

1. Esperar 2-3 minutos hasta que las instancias estén `InService`
2. Verificar en la pestaña **Instances** del ASG que el estado sea `Service`
3. Verificar en **Target Groups** > `tg-web-servers` > **Targets** que las instancias aparezcan como `healthy`

---

## Paso 4: Crear instancia de aplicación

### 4.1 Crear instancia EC2 para aplicación

1. Ir a **EC2** > **Instances** > **Launch instances**
2. Configurar:
   - **Name**: `app-server-1`
   - **AMI**: Amazon Linux 2023 (versión más reciente disponible en el AMI Catalog)
   - **Instance type**: `t3.small`
   - **Network**: `mi-vpc`
   - **Subnet**: private subnet en AZ-1
   - **Security groups**: `sg-app` (permitir HTTP desde `sg-web`)
   - **Auto-assign Public IP**: Disable
3. Clic en **Launch instance**

### 4.2 Instalar aplicación de ejemplo

1. Conectarse a la instancia vía Session Manager o bastion host
2. Ejecutar:

```bash
sudo dnf update -y
sudo dnf install -y python3 python3-pip

# Crear entorno virtual para aislar dependencias (requerido en AL2023)
python3 -m venv /home/ec2-user/venv
source /home/ec2-user/venv/bin/activate

pip install flask boto3

cat > /home/ec2-user/app.py << 'EOF'
from flask import Flask
import boto3
import os

app = Flask(__name__)

@app.route('/')
def index():
    return 'Application server responding successfully'

@app.route('/health')
def health():
    return {'status': 'healthy'}

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
EOF

# Activar el venv antes de lanzar (si se reconecta a la instancia)
source /home/ec2-user/venv/bin/activate
nohup python3 /home/ec2-user/app.py > /tmp/app.log 2>&1 &
# Nota: esta forma de lanzar no persiste tras reboot; es suficiente para este lab
```

---

## Paso 5: Crear RDS Multi-AZ

### 5.1 Crear el grupo de subnets

1. Ir a **RDS** > **Subnet groups** > **Create DB Subnet Group**
2. Configurar:
   - **Name**: `mi-db-subnet-group`
   - **Description**: `Subnet group for RDS Multi-AZ`
   - **VPC**: `mi-vpc`
   - **Availability Zones**: seleccionar 3 AZs
   - **Subnets**: seleccionar las 3 subnets privadas

### 5.2 Crear la base de datos RDS

1. Ir a **RDS** > **Databases** > **Create database**
2. **Engine options**:
   - **Engine type**: MySQL
   - **Version**: Seleccionar la versión más reciente disponible (MySQL 8.0.x o 8.4.x según disponibilidad en la consola)

3. **Templates**: seleccionar **Free tier** (para demo) o **Production** (para Multi-AZ real)

4. **Settings**:
   - **DB instance identifier**: `mi-db`
   - **Master username**: `admin`
   - **Master password**: (usar password generator seguro)

5. **Instance configuration**:
   - **DB instance class**: `db.t3.micro`

6. **Connectivity**:
   - **Virtual private cloud (VPC)**: `mi-vpc`
   - **Subnet group**: `mi-db-subnet-group`
   - **Public access**: `No`
   - **VPC security group**: crear nuevo `sg-db` con regla entrada:
     - Type: MySQL/Aurora
     - Port: 3306
     - Source: `sg-app`
   - **Multi-AZ deployment**: seleccionar **Create a standby instance** (para producción) o **Dev/Test** (para demo con Multi-AZ)

7. **Additional configuration**:
   - **Initial database name**: `miappdb`
   - **Backup**: Enable, retention 1 day
   - **Encryption**: Enable (recomendado para producción)

8. Clic en **Create database**

### 5.3 Verificar despliegue de RDS

1. Esperar 10-15 minutos hasta que el estado sea `Available`
2. Verificar que en **Configuration** aparezca:
   - **Multi-AZ**: Yes (o Available)
   - **Primary AZ** y **Secondary AZ** identificados

---

## Paso 6: Configurar Health Checks en Route 53

### 6.1 Crear Health Check

1. Ir a **Route 53** > **Health checks** > **Create health check**
2. Configurar:
   - **Name**: `hc-alb`
   - **What to monitor**: Endpoint
   - **Specify endpoint**: Yes
   - **Domain name**: (ingresar el DNS del ALB creado anteriormente)
   - **Protocol**: HTTP
   - **Port**: 80
   - **Path**: `/index.html`
   - **Request interval**: 30 seconds (Standard)
   - **Failure threshold**: 3

3. Clic en **Create**

### 6.2 Verificar Health Check

1. Esperar 30-60 segundos hasta que el estado sea **Healthy**
2. Si aparece **Healthy**, el health check está funcionando

---

## Paso 7: Verificar la Arquitectura Completa

### 7.1 Probar acceso web

1. Obtener el DNS del ALB:
```bash
aws elbv2 describe-load-balancers \
  --names mi-alb-web \
  --query 'LoadBalancers[0].DNSName' \
  --output text
```

2. Abrir en el navegador: `http://<alb-dns>/index.html`

3. Verificar que la página muestra:
   - Instance ID de la instancia que responde
   - Availability Zone
   - IP privada

4. Refrescar varias veces para ver cómo el ALB distribuye tráfico entre AZs

### 7.2 Simular fallo y verificar auto-recuperación

1. **Identificar una instancia del ASG**:
```bash
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names asg-web-tier \
  --query 'AutoScalingGroups[0].Instances[*].InstanceId' \
  --output text
```

2. **Terminar una instancia** (reemplazar `<instance-id>` con el ID obtenido):
```bash
aws ec2 terminate-instances --instance-ids <instance-id>
```

3. **Observar recuperación automática**:
   - En la consola EC2, verificar que el ASG detecta la terminación
   - En 60-90 segundos, una nueva instancia debe ser lanzada automáticamente
   - El ALB detecta la nueva instancia y la registra en el target group

4. **Verificar continuidad del servicio**:
   - Refrescar el navegador - el servicio sigue respondiendo (desde otra AZ)

### 7.3 Verificar logs de aplicación

1. Conectarse a la instancia de aplicación (app-server-1)
2. Revisar logs de la aplicación:
```bash
tail -f /tmp/app.log
```

---

## Verificación Final

Al completar este lab, debes ser capaz de:

- [ ] Crear un Application Load Balancer (ALB) con target groups
- [ ] Configurar Launch Templates para instancias EC2
- [ ] Implementar Auto Scaling Groups con políticas de escalamiento
- [ ] Crear una base de datos RDS con Multi-AZ
- [ ] Configurar Security Groups para comunicación entre capas
- [ ] Verificar el failover automático cuando una instancia falla
- [ ] Explicar cómo cada componente contribuye a la alta disponibilidad

---

## Errores Comunes y Soluciones

| Error | Causa | Solución |
|-------|-------|----------|
| Instancias en estado `Unhealthy` | Security group no permite tráfico del ALB | Verificar que `sg-web` permite tráfico en puerto 80 desde el ALB |
| Health check falla constantemente | Health check path no existe o returns non-200 | Verificar que Apache está corriendo y responde en `/index.html` |
| ASG no lanza instancias | Límite de recursos en la cuenta | Verificar límites de EC2 o seleccionar instance type diferente |
| RDS Multi-AZ no se crea | Subnet group incompleto | Asegurar que hay subnets en al menos 2 AZs en el subnet group |
| No se puede conectar a RDS | Security group no permite acceso | Agregar regla en `sg-db` para permitir puerto 3306 desde `sg-app` |
| ALB DNS no resuelve | DNS aún propagándose | Esperar unos minutos o usar el DNS name directamente |

---

## Limpieza de Recursos

Para evitar costos innecesarios, al finalizar el lab ejecutar:

```bash
# Eliminar ASG (desasociar primero de Load Balancer)
aws autoscaling delete-auto-scaling-group --auto-scaling-group-name asg-web-tier --force-delete

# Eliminar Launch Template
aws ec2 delete-launch-template --launch-template-name lt-web-tier

# Eliminar ALB
aws elbv2 delete-load-balancer --load-balancer-arn <alb-arn>

# Eliminar Target Group
aws elbv2 delete-target-group --target-group-arn <tg-arn>

# Eliminar RDS (último, después de backups)
aws rds delete-db-instance --db-instance-identifier mi-db --skip-final-snapshot
```
