# Lab 7.1: Desplegar Aplicación en Contenedores con ECS Fargate

## Objetivo

Desplegar una aplicación web en contenedores usando Amazon ECS con launch type Fargate, creando un repositorio en ECR, configurando un cluster, task definition y service con load balancer.

---

## Duración Estimada

**60 minutos**

---

## Prerrequisitos

- Cuenta AWS con permisos para ECS, ECR, IAM, VPC, EC2, ELB
- Docker instalado localmente (`docker --version`)
- AWS CLI configurado con credenciales válidas (`aws configure`)
- Familiaridad básica con la consola de AWS

---

## Recursos Necesarios

- Aplicación web de ejemplo (proporcionada en el directorio `app/`)
- VPC con al menos 2 subnets privadas en diferentes AZs
- Security Group con inbound en puerto 8000 (contenedor) y puerto 80 (ALB)

---

## Pasos

### Paso 1: Crear Repositorio ECR

En este paso crearás un repositorio privado en Amazon ECR para almacenar tu imagen Docker.

1.1. Abre la consola de AWS y navega a **Amazon ECR** (busca "ECR" en el menú de servicios).

1.2. Haz clic en **"Get started"** o **"Create repository"**.

1.3. En la configuración del repositorio:
   - **Repository name**: `my-webapp`
   - **Image tag mutability**: `MUTABLE`
   - **Scan on push**: Selecciona **Enable**

1.4. Haz clic en **"Create repository"**.

1.5. Una vez creado, guarda la URI del repositorio que aparece en la consola, tendrá el formato:
   ```
   <account-id>.dkr.ecr.us-east-1.amazonaws.com/my-webapp
   ```

---

### Paso 2: Construir y Push Imagen Docker

En este paso construirás la imagen Docker localmente y la subirás a tu repositorio ECR.

2.1. Abre una terminal y navega al directorio de la aplicación:
   ```bash
   cd app/
   ```

2.2. autentícate en ECR:
   ```bash
   aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.us-east-1.amazonaws.com
   ```
   Deberías ver el mensaje: `Login Succeeded`

2.3. Construye la imagen Docker:
   ```bash
   docker build -t my-webapp:latest .
   ```

2.4. Etiqueta la imagen para ECR:
   ```bash
   docker tag my-webapp:latest <account-id>.dkr.ecr.us-east-1.amazonaws.com/my-webapp:latest
   ```

2.5. Sube la imagen a ECR:
   ```bash
   docker push <account-id>.dkr.ecr.us-east-1.amazonaws.com/my-webapp:latest
   ```

2.6. Verifica que la imagen aparece en el repositorio ECR en la consola de AWS.

---

### Paso 3: Crear Cluster ECS con Fargate

En este paso crearás un cluster de ECS que utilizará Fargate como tipo de infraestructura.

3.1. Navega a **Amazon ECS** en la consola de AWS.

3.2. En el menú lateral, haz clic en **"Clusters"**.

3.3. Haz clic en **"Create cluster"**.

3.4. En la configuración del cluster:
   - **Cluster name**: `my-cluster`
   - **Infrastructure**: Selecciona **AWS Fargate**

   > **Nota:** En la consola actual de ECS la creación del cluster NO incluye configuración de VPC ni subnets. Esas opciones se configuran más adelante al crear el Service (Paso 5).

3.5. Expande la sección **"Monitoring"** y asegúrate de que **"Container Insights"** esté habilitado.

3.6. Haz clic en **"Create"**.

3.7. Espera a que el cluster cambie al estado **"ACTIVE"** (aproximadamente 2-3 minutos).

---

### Paso 4: Crear Task Definition

La task definition es el blueprint que define cómo se ejecutará tu contenedor.

4.1. En el menú lateral de ECS, haz clic en **"Task definitions"**.

4.2. Haz clic en **"Create new Task Definition"**.

4.3. Selecciona **"Fargate"** como launch type compatibility.

4.4. En la configuración de la task definition:
   - **Task definition family**: `my-webapp-task`
   - **Task execution role**: Selecciona **"ecsTaskExecutionRole"** (o créala si no existe)
   - **Operating system family**: `Linux`
   - **Network mode**: `awsvpc`
   - **Task size**:
     - **CPU**: `0.25 vCPU`
     - **Memory**: `0.5 GB`

4.5. En la sección **"Container - 1"**:
   - **Container name**: `webapp`
   - **Image**: Pega la URI de tu imagen ECR: `<account-id>.dkr.ecr.us-east-1.amazonaws.com/my-webapp:latest`
   - **Port mappings**:
     - **Container port**: `8000`
     - **Protocol**: `tcp`
   - **Essential container**: Verificado (yes)
   - **Environment**:
     - **Memory Limits**: Soft limit `512`
   - **Health check**: Deja los valores por defecto

4.6. Haz clic en **"Create"**.

---

### Paso 5: Crear Service con Application Load Balancer

En este paso crearás un ECS Service que mantendrárunning tus tareas y las distribuirá con un ALB.

5.1. Ve a tu cluster `my-cluster` y haz clic en la pestaña **"Services"**.

5.2. Haz clic en **"Create"**.

5.3. En la configuración del service:
   - **Launch type**: `Fargate`
   - **Task Definition**: Selecciona `my-webapp-task`
   - **Revision**: Latest
   - **Platform version**: `LATEST`
   - **Service name**: `my-webapp-service`
   - **Number of tasks**: `2`
   - **Minimum healthy percent**: `100`
   - **Maximum percent**: `200`

5.4. En **"Deployment circuit breaker"**: Habilita la opción con rollback.

5.5. En **"Network configuration"**:
   - **Cluster VPC**: Selecciona la VPC que creaste (`10.0.0.0/16`)
   - **Subnets**: Selecciona las 2 subnets privadas
   - **Security group**: Crea uno nuevo con regla inbound para `8000` desde el CIDR de la VPC (`10.0.0.0/16`)
   - **Auto-assign public IP**: `DISABLE`

5.6. En **"Load balancing"**:
   - **Load balancer type**: `Application Load Balancer`
   - **Select an existing load balancer**: `Create a new load balancer`
   - **Load balancer name**: `my-webapp-alb`
   - **Target group name**: `my-webapp-tg`

5.7. En **"Container to load balance"**:
   - Verifica que `webapp:8000` está listado
   - **Production listener port**: `80:HTTP`
   - **Target group**: `my-webapp-tg`

5.8. Haz clic en **"Create"**.

5.9. Espera a que el service cambie al estado **"ACTIVE"** (puede tomar 5-7 minutos).

---

### Paso 6: Configurar Health Check en Target Group

6.1. Navega a **EC2** > **Target Groups**.

6.2. Selecciona el target group `my-webapp-tg`.

6.3. Haz clic en la pestaña **"Health checks"**.

6.4. Verifica o configura:
   - **Protocol**: `HTTP`
   - **Path**: `/`
   - **Port**: `traffic port`
   - **Healthy threshold**: `2`
   - **Unhealthy threshold**: `3`
   - **Timeout**: `5 seconds`
   - **Interval**: `30 seconds`

6.5. Haz clic en **"Save"**.

---

### Paso 7: Verificar el Deployment

7.1. Obtén el DNS del Application Load Balancer:
   ```bash
   aws elbv2 describe-load-balancers --names my-webapp-alb --query 'LoadBalancers[0].DNSName' --output text
   ```

7.2. Copia el DNS name y abre un navegador web.

7.3. Accede a la aplicación en: `http://<alb-dns-name>` (el ALB escucha en el puerto 80 y enruta al contenedor en el puerto 8000)

   Deberías ver la página de bienvenida de tu aplicación web.

7.4. Verifica el estado del service en la consola de ECS:
   ```bash
   aws ecs describe-services --cluster my-cluster --services my-webapp-service --query 'services[0]'
   ```

7.5. Verifica las tareas en ejecución:
   ```bash
   aws ecs list-tasks --cluster my-cluster --service-name my-webapp-service
   ```

7.6. Opcional: Verifica los logs del contenedor:
   ```bash
   aws ecs describe-tasks --cluster my-cluster --tasks <task-arn> --query 'tasks[0].containers[0].logConfiguration'
   ```

---

## Criterios de Verificación

Al finalizar este lab, debes poder confirmar que:

- [ ] El repositorio ECR `my-webapp` fue creado exitosamente
- [ ] La imagen Docker fue construida y subida a ECR correctamente
- [ ] El cluster ECS `my-cluster` está en estado ACTIVE con Fargate
- [ ] La task definition `my-webapp-task` fue creada con la imagen de ECR
- [ ] El service `my-webapp-service` tiene 2 tareas en estado RUNNING
- [ ] El Application Load Balancer `my-webapp-alb` está activo
- [ ] La aplicación es accesible via navegador en `http://<alb-dns>` (puerto 80)
- [ ] El health check del target group muestra las tareas como HEALTHY

---

## Errores Comunes y Soluciones

| Error | Causa | Solución |
|-------|-------|----------|
| `No Container Instances available` | El cluster usa EC2 pero no hay instancias registradas | Asegúrate de usar Fargate o lanzar instancias EC2 con el ECS agent |
| `Image not found` | La URI de la imagen en ECR es incorrecta | Verifica que la imagen existe en ECR y la URI está bien escrita |
| `Health check failed` | La aplicación no responde en el path configurado | Verifica que la aplicación escucha en el puerto correcto y responde a HTTP GET |
| `Security group denied` | El security group no permite tráfico en el puerto | Edita el security group: inbound 80 para el ALB y 8000 desde el SG del ALB para las tareas ECS |
| `Service failed to start` | Falta el rol IAM ecsTaskExecutionRole | Crea el rol IAM con la política AmazonECSTaskExecutionRolePolicy |
| `Subnet has no routable Internet connection` | Las subnets privadas no tienen NAT Gateway | Asegúrate de que las subnets tengan ruta a Internet via NAT Gateway o VPC Endpoint |

---

## Limpieza de Recursos

Para evitar costos innecesarios, elimina los recursos creados:

```bash
# Eliminar el service
aws ecs delete-service --cluster my-cluster --service my-webapp-service --force

# Eliminar el cluster
aws ecs delete-cluster --cluster my-cluster

# Eliminar el Application Load Balancer
ALB_ARN=$(aws elbv2 describe-load-balancers --names my-webapp-alb --query 'LoadBalancers[0].LoadBalancerArn' --output text)
aws elbv2 delete-load-balancer --load-balancer-arn $ALB_ARN

# Esperar a que el ALB sea eliminado y luego eliminar el Target Group
TG_ARN=$(aws elbv2 describe-target-groups --names my-webapp-tg --query 'TargetGroups[0].TargetGroupArn' --output text)
aws elbv2 delete-target-group --target-group-arn $TG_ARN

# Eliminar la imagen de ECR (batch-delete-image es el comando correcto)
aws ecr batch-delete-image \
  --repository-name my-webapp \
  --image-ids imageTag=latest

# Eliminar el repositorio ECR
aws ecr delete-repository --repository-name my-webapp --force
```

---

## Referencias

- [Amazon ECS Developer Guide](https://docs.aws.amazon.com/ecs/latest/developerguide/)
- [Amazon ECR User Guide](https://docs.aws.amazon.com/ecr/latest/userguide/)
- [AWS Fargate Documentation](https://docs.aws.amazon.com/AmazonECS/latest/userguide/what-is-fargate.html)
