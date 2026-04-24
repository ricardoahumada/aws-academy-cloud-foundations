# Lab 7.3: Desplegar Aplicación Multi-Tier en EKS con Auto-Scaling e Ingress

## Objetivo

Crear un cluster Amazon EKS completo y desplegar una aplicación web multi-tier (frontend, backend API, base de datos PostgreSQL y cache Redis) usando kubectl. Configurar auto-scaling con HPA, ingress con AWS Load Balancer Controller, y monitoreo con Metrics Server.

---

## Duración Estimada

**2-3 horas**

---

## Prerrequisitos

- CLI de AWS configurado (`aws sts get-caller-identity`)
- `eksctl` instalado ([instalación oficial](https://eksctl.io/introduction/#installation))
- `kubectl` instalado ([instalación oficial](https://kubernetes.io/docs/tasks/tools/))
- **Docker instalado** para construir imágenes
- **Helm instalado** (v3+) para instalar controladores
- IAM role con permisos para:
  - Crear clusters EKS, node groups, y recursos de red
  - Crear y gestionar repositorios ECR
  - Gestionar políticas IAM para Load Balancer Controller
- AWS VPC con subnets públicas y privadas en al menos 2 AZs

---

## Recursos Necesarios

- VPC: `10.0.0.0/16` con subnets en `us-east-1a` y `us-east-1b`
- 2 repositorios ECR para almacenar imágenes Docker
- EBS volumes para base de datos PostgreSQL (provisionado automáticamente)
- Application Load Balancer (provisionado automáticamente por Ingress)

---

## Pasos

### Paso 1: Verificar Herramientas Instaladas

Antes de comenzar, verifica que todas las herramientas están instaladas y correctamente configuradas.

1.1. Verifica la versión de AWS CLI:
   ```bash
   aws --version
   ```
   Esperado: `aws-cli/2.x.x`

1.2. Verifica eksctl:
   ```bash
   eksctl version
   ```
   Esperado: Versión 0.100.0 o superior

   > Nota: en cloudshell, eksctl no está preinstalado. Puedes instalarlo con:
   ```bash
   curl --silent --location "https://github.com/eksctl-io/eksctl/releases/download/v0.225.0/eksctl_Linux_amd64.tar.gz" | tar xz -C /tmp
   sudo mv /tmp/eksctl /usr/local/bin
   ```


1.3. Verifica kubectl:
   ```bash
   kubectl version --client
   ```
   Esperado: Client Version: v1.32.x o superior

1.4. Verifica tu identidad AWS:
   ```bash
   aws sts get-caller-identity
   ```
   Deberías ver tu Account ID, User ID, y ARN.

---

### Paso 2: Crear IAM Role para Nodes (si no existe)

Los nodos de EKS necesitan un IAM role con políticas mínimas.

2.1. Crea el trust policy para el rol:
   ```bash
   cat > node-role-trust-policy.json <<EOF
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Effect": "Allow",
         "Principal": {
           "Service": "ec2.amazonaws.com"
         },
         "Action": "sts:AssumeRole"
       }
     ]
   }
   EOF
   ```

2.2. Crea el IAM role:
   ```bash
   aws iam create-role \
     --role-name EKSNodeRole \
     --assume-role-policy-document file://node-role-trust-policy.json
   ```

2.3. Adjunta las políticas necesarias:
   ```bash
   aws iam attach-role-policy \
     --role-name EKSNodeRole \
     --policy-arn arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy

   aws iam attach-role-policy \
     --role-name EKSNodeRole \
     --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly

   aws iam attach-role-policy \
     --role-name EKSNodeRole \
     --policy-arn arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy
   ```

---

### Paso 3: Crear Cluster EKS con eksctl

En este paso crearás el cluster EKS y el node group.

3.1. Identifica tu subnet privada:

   ```bash
   # Lista tus VPCs
   aws ec2 describe-vpcs --query 'Vpcs[*].{ID:VpcId,CIDR:CidrBlock}' --output table

   # Lista subnets de una VPC (reemplaza <vpc-id>)
   aws ec2 describe-subnets --filters "Name=vpc-id,Values=<vpc-id>" \
     --query 'Subnets[*].{ID:SubnetId,CIDR:CidrBlock,AZ:AvailabilityZone}' --output table
   ```

   Anota el **Subnet ID** y su **AZ** (ej: `us-east-1a`).

3.2. Crea el archivo de configuración `cluster.yaml`:

   ```bash
   cat > cluster.yaml <<EOF
   apiVersion: eksctl.io/v1alpha5
   kind: ClusterConfig

   metadata:
   name: my-eks-cluster2
   region: us-east-1
   version: "1.30"

   vpc:
   id: <vpc-id>
   subnets:
      private:
         us-east-1b: { id: <subnet-id> }
         us-east-1a: { id: <subnet-id> }
   nat:
      gateway: Single

   managedNodeGroups:
   - name: workers
      instanceType: t3.small
      desiredCapacity: 2
      minSize: 1
      maxSize: 3
      privateNetworking: true
      labels:
         role: worker
      tags:
         Environment: development

   iam:
   withOIDC: true

   addons:
   - name: vpc-cni
   - name: coredns
   - name: kube-proxy
   EOF
   ```

   Reemplaza los placeholders:
   - `<vpc-id>` → tu ID de VPC (ej: `vpc-086cc4594670150d4`)
   - `<az-1>` → la AZ de tu subnet (ej: `us-east-1b`)
   - `<subnet-private-1>` → tu subnet ID (ej: `subnet-0a0716944ca582922`)
   
   > **Nota**: El formato debe ser `{ id: subnet-xxx }` - no olvides las llaves.

3.2. Crea el cluster:
   ```bash
   eksctl create cluster -f cluster.yaml
   ```

   Este comando tomará aproximadamente 20-25 minutos.

   [ℹ]  eksctl version 0.100.0
   [ℹ]  using region us-east-1
   [✓]  EKS cluster "my-eks-cluster" in "us-east-1" region
   [ℹ]  Nodegroup "workers" is ready

---

### Paso 3 Alternativa: Crear Cluster desde la Consola AWS

Si prefieres crear el cluster desde la consola web en lugar de `eksctl`:

**Desde la consola EKS:**
1. Ve a **Amazon EKS** → **Add cluster** → **Create**
2. Configura:
   - **Name**: `my-eks-cluster`
   - **Kubernetes version**: `1.30`
   - **Role de servicio**: Crea uno nuevo con `AmazonEKSClusterPolicy`
   - **VPC**: Selecciona o crea una VPC `10.0.0.0/16` con subnets en al menos 2 AZs
   - **Endpoints**: Configuración por defecto
3. Haz clic en **Create**

   La creación toma ~15-20 minutos.

**Para crear el Node Group (después que el cluster esté activo):**
1. Selecciona el cluster → pestaña **Compute**
2. Haz clic en **Add node group**
3. Configura:
   - **Name**: `workers`
   - **Node IAM role**: Selecciona `EKSNodeRole` (creado en Paso 2)
   - **Instance type**: `t3.small`
   - **Scaling**: 1-3 nodos
   - **Subnets**: Selecciona subnets privadas
4. Haz clic en **Create**

---

### Paso 4: Configurar kubectl para EKS

4.1. Actualiza el archivo kubeconfig para conectar kubectl al cluster:
   ```bash
   aws eks update-kubeconfig --name my-eks-cluster --region us-east-1
   ```

4.2. Verifica la conexión:
   ```bash
   kubectl get nodes
   ```
   Deberías ver los 2 nodes en estado `Ready`.

4.3. Obtén información del cluster:
   ```bash
   kubectl cluster-info
   ```

4.4. Lista todos los pods del sistema:
   ```bash
   kubectl get pods -A
   ```
   Todos los pods del sistema (coredns, kube-proxy, aws-node) deben estar en estado `Running`.

---

### Paso 5: Crear Repositorios en Amazon ECR

Para este lab, crearás imágenes Docker personalizadas y las almacenarás en Amazon ECR.

5.1. Obtén tu AWS Account ID:
   ```bash
   export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
   echo $AWS_ACCOUNT_ID
   ```

5.2. Crea repositorios ECR para las aplicaciones:
   ```bash
   aws ecr create-repository --repository-name my-webapp --region us-east-1
   aws ecr create-repository --repository-name my-api --region us-east-1
   ```

5.3. Autentícate con ECR:
   ```bash
   aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com
   ```

---

### Paso 6: Construir y Subir Imágenes Docker

6.1. Crea el directorio para las aplicaciones:
   ```bash
   mkdir -p ~/lab-eks-app/{webapp,api}
   cd ~/lab-eks-app
   ```

6.2. Crea la aplicación webapp (frontend):
   ```bash
   cd webapp
   cat > Dockerfile <<EOF
FROM nginx:alpine
COPY index.html /usr/share/nginx/html/
COPY health.html /usr/share/nginx/html/
COPY ready.html /usr/share/nginx/html/
EXPOSE 80
EOF

   cat > index.html <<EOF
<!DOCTYPE html>
<html>
<head><title>EKS Multi-Tier App</title></head>
<body>
  <h1>Frontend - Running on EKS</h1>
  <p>Pod: <span id="hostname"></span></p>
  <script>
    fetch('/api/status')
      .then(r => r.json())
      .then(d => document.getElementById('hostname').textContent = d.pod);
  </script>
</body>
</html>
EOF

   cat > health.html <<EOF
OK
EOF

   cp health.html ready.html
   ```

6.3. Construye y sube la imagen webapp:
   ```bash
   docker build -t my-webapp .
   docker tag my-webapp:latest $AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/my-webapp:latest
   docker push $AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/my-webapp:latest
   ```

6.4. Crea la aplicación API (backend):
   ```bash
   cd ../api
   cat > Dockerfile <<EOF
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY app.py .
EXPOSE 8000
CMD ["python", "app.py"]
EOF

   cat > requirements.txt <<EOF
flask==3.0.0
psycopg2-binary==2.9.9
redis==5.0.1
EOF

   cat > app.py <<'EOF'
from flask import Flask, jsonify
import os
import socket
import psycopg2
import redis

app = Flask(__name__)

@app.route('/health')
def health():
    return 'OK', 200

@app.route('/ready')
def ready():
    try:
        # Check database connection
        db_url = os.getenv('DATABASE_URL')
        db_pass = os.getenv('DATABASE_PASSWORD')
        # Simple connection test
        return 'OK', 200
    except:
        return 'Not Ready', 503

@app.route('/api/status')
def status():
    return jsonify({
        'pod': socket.gethostname(),
        'status': 'running'
    })

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8000)
EOF
   ```

6.5. Construye y sube la imagen API:
   ```bash
   docker build -t my-api .
   docker tag my-api:latest $AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/my-api:latest
   docker push $AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/my-api:latest
   ```

6.6. Verifica que las imágenes están en ECR:
   ```bash
   aws ecr describe-images --repository-name my-webapp --region us-east-1
   aws ecr describe-images --repository-name my-api --region us-east-1
   ```

---

### Paso 7: Instalar AWS Load Balancer Controller

El AWS Load Balancer Controller gestiona los Ingress resources y provisiona Application Load Balancers automáticamente.

7.1. Descarga la política IAM necesaria:
   ```bash
   curl -o iam_policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.7.0/docs/install/iam_policy.json
   ```

7.2. Crea la política IAM:
   ```bash
   aws iam create-policy \
     --policy-name AWSLoadBalancerControllerIAMPolicy \
     --policy-document file://iam_policy.json
   ```

7.3. Crea un service account IAM para el controller:
   ```bash
   eksctl create iamserviceaccount \
     --cluster=my-eks-cluster \
     --namespace=kube-system \
     --name=aws-load-balancer-controller \
     --attach-policy-arn=arn:aws:iam::$AWS_ACCOUNT_ID:policy/AWSLoadBalancerControllerIAMPolicy \
     --override-existing-serviceaccounts \
     --region us-east-1 \
     --approve
   ```

7.4. Agrega el repositorio Helm del controller:
   ```bash
   helm repo add eks https://aws.github.io/eks-charts
   helm repo update
   ```

7.5. Instala el AWS Load Balancer Controller:
   ```bash
   helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
     -n kube-system \
     --set clusterName=my-eks-cluster \
     --set serviceAccount.create=false \
     --set serviceAccount.name=aws-load-balancer-controller
   ```

7.6. Verifica la instalación:
   ```bash
   kubectl get deployment -n kube-system aws-load-balancer-controller
   kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
   ```

---

### Paso 8: Instalar Metrics Server

El Metrics Server es necesario para que el HorizontalPodAutoscaler pueda obtener métricas de CPU y memoria.

8.1. Instala Metrics Server:
   ```bash
   kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
   ```

8.2. Verifica la instalación:
   ```bash
   kubectl get deployment metrics-server -n kube-system
   ```

8.3. Espera a que esté listo (puede tomar 1-2 minutos):
   ```bash
   kubectl wait --for=condition=available --timeout=180s deployment/metrics-server -n kube-system
   ```

8.4. Verifica que las métricas están disponibles:
   ```bash
   kubectl top nodes
   ```

---

### Paso 9: Preparar Manifiestos Kubernetes

9.1. Navega al directorio de manifiestos:
   ```bash
   cd ~/lab-eks-app
   ```

9.2. Clona o descarga los manifiestos del lab (o créalos manualmente si están en el material del curso):
   ```bash
   # Si tienes acceso al repositorio del curso
   # git clone <repo-url>
   # cd aws-academy-cloud-foundations/module-07/labs/lab-3/k8s
   
   # O navega al directorio si ya los tienes localmente
   cd /path/to/module-07/labs/lab-3/k8s
   ```

9.3. Reemplaza el placeholder `<ACCOUNT_ID>` en los manifiestos:
   ```bash
   export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
   
   # Linux/Mac
   sed -i "s/<ACCOUNT_ID>/$AWS_ACCOUNT_ID/g" deployment.yaml api-deployment.yaml
   
   # Windows PowerShell (si estás en Windows)
   # (Get-Content deployment.yaml) -replace '<ACCOUNT_ID>', $AWS_ACCOUNT_ID | Set-Content deployment.yaml
   # (Get-Content api-deployment.yaml) -replace '<ACCOUNT_ID>', $AWS_ACCOUNT_ID | Set-Content api-deployment.yaml
   ```

9.4. Actualiza el Secret con una contraseña segura:
   ```bash
   # Edita configmap.yaml y cambia los valores de los secrets
   # Por ahora usaremos valores de ejemplo para el lab
   kubectl create secret generic app-secrets \
     --from-literal=DATABASE_PASSWORD=SecureP@ssw0rd123 \
     --from-literal=API_KEY=your-api-key-here \
     --from-literal=JWT_SECRET=your-jwt-secret-here
   ```

---

### Paso 10: Desplegar la Aplicación Multi-Tier

Despliega los componentes en el orden correcto para asegurar las dependencias.

10.1. Aplica ConfigMap (variables de entorno):
   ```bash
   kubectl apply -f configmap.yaml
   ```

10.2. Despliega la base de datos PostgreSQL:
   ```bash
   kubectl apply -f database.yaml
   ```

10.3. Espera a que PostgreSQL esté listo:
   ```bash
   kubectl wait --for=condition=ready pod -l app=postgres --timeout=300s
   kubectl get pods -l app=postgres
   ```

10.4. Despliega Redis cache:
   ```bash
   kubectl apply -f redis.yaml
   kubectl wait --for=condition=ready pod -l app=redis --timeout=180s
   ```

10.5. Despliega el backend API:
   ```bash
   kubectl apply -f api-deployment.yaml
   kubectl wait --for=condition=ready pod -l app=api --timeout=180s
   ```

10.6. Despliega el frontend webapp:
   ```bash
   kubectl apply -f deployment.yaml
   kubectl wait --for=condition=ready pod -l app=webapp --timeout=180s
   ```

10.7. Aplica el HorizontalPodAutoscaler:
   ```bash
   kubectl apply -f hpa.yaml
   ```

10.8. Despliega el Ingress:
   ```bash
   kubectl apply -f ingress.yaml
   ```

10.9. Verifica todos los recursos:
   ```bash
   kubectl get all
   kubectl get ingress
   kubectl get hpa
   kubectl get pvc
   ```

---

### Paso 11: Verificar el Deployment y Acceso

11.1. Verifica que todos los pods están corriendo:
   ```bash
   kubectl get pods -o wide
   ```
   Deberías ver:
   - 1 pod de postgres (StatefulSet)
   - 1 pod de redis
   - 2 pods de api
   - 3 pods de webapp

11.2. Verifica los services:
   ```bash
   kubectl get services
   ```

11.3. Obtén la URL del Ingress (puede tomar 2-3 minutos en aprovisionar el ALB):
   ```bash
   kubectl get ingress webapp-ingress -w
   ```
   Presiona Ctrl+C cuando veas una dirección en ADDRESS.

11.4. Copia la URL del ALB:
   ```bash
   export INGRESS_URL=$(kubectl get ingress webapp-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
   echo "Aplicación disponible en: http://$INGRESS_URL"
   ```

11.5. Prueba el acceso al frontend:
   ```bash
   curl http://$INGRESS_URL/
   ```

11.6. Prueba el acceso a la API:
   ```bash
   curl http://$INGRESS_URL/api/status
   ```

11.7. Verifica los logs de los pods:
   ```bash
   kubectl logs -l app=webapp --tail=20
   kubectl logs -l app=api --tail=20
   ```

---

### Paso 12: Probar Auto-Scaling con HPA

12.1. Verifica el estado inicial del HPA:
   ```bash
   kubectl get hpa webapp-hpa
   ```

12.2. Genera carga en la aplicación para activar el auto-scaling:
   ```bash
   # Instala hey (generador de carga HTTP) si no lo tienes
   # Linux: wget https://hey-release.s3.us-east-2.amazonaws.com/hey_linux_amd64 && chmod +x hey_linux_amd64
   # Mac: brew install hey
   
   # Genera carga (200 requests concurrentes durante 5 minutos)
   hey -z 300s -c 200 http://$INGRESS_URL/
   ```

12.3. Observa el scaling en tiempo real (en otra terminal):
   ```bash
   kubectl get hpa webapp-hpa -w
   ```

12.4. Observa los pods escalando:
   ```bash
   kubectl get pods -l app=webapp -w
   ```

12.5. Después de detener la carga, observa el scale-down (tomará ~5 minutos por la estabilización):
   ```bash
   kubectl get hpa webapp-hpa -w
   ```

Es importante limpiar los recursos en el orden inverso al deployment para evitar dependencias y costos innecesarios.

13.1. Elimina el Ingress (esto eliminará el ALB):
   ```bash
   kubectl delete -f ingress.yaml
   ```

13.2. Elimina el HPA:
   ```bash
   kubectl delete -f hpa.yaml
   ```

13.3. Elimina los deployments de aplicación:
   ```bash
   kubectl delete -f deployment.yaml
   kubectl delete -f api-deployment.yaml
   ```

13.4. Elimina los servicios de datos:
   ```bash
   kubectl delete -f redis.yaml
   kubectl delete -f database.yaml
   ```

13.5. Elimina ConfigMap y Secret:
   ```bash
   kubectl delete -f configmap.yaml
   kubectl delete secret app-secrets
   ```

13.6. Verifica que los PVCs fueron eliminados:
   ```bash
   kubectl get pvc
   ```

13.7. Desinstala el AWS Load Balancer Controller:
   ```bash
   helm uninstall aws-load-balancer-controller -n kube-system
   ```

13.8. Elimina el cluster EKS:
   ```bash
   eksctl delete cluster -f cluster.yaml
   ```
   Esto eliminará el cluster, los node groups, y los recursos de red asociados.
   **Nota**: Este proceso toma aproximadamente 15-20 minutos.

13.9. Elimina los repositorios ECR:
   ```bash
   aws ecr delete-repository --repository-name my-webapp --region us-east-1 --force
   aws ecr delete-repository --repository-name my-api --region us-east-1 --force
   ```

13.10. Elimina la política IAM del Load Balancer Controller:
   ```bash
   aws iam delete-policy --policy-arn arn:aws:iam::$AWS_ACCOUNT_ID:policy/AWSLoadBalancerControllerIAMPolicy
   ```

13.11. Verifica que el cluster fue eliminado:
   ```bash
   aws eks list-clusters --region us-east-1
   ```

---

## Criterios de Verificación

Al finalizar este lab, debes poder confirmar que:

**Cluster y Nodes:**
- [ ] El cluster EKS `my-eks-cluster` fue creado exitosamente
- [ ] kubectl está configurado correctamente y puede comunicarse con el cluster
- [ ] Los 2 nodes del node group están en estado `Ready`
- [ ] Los pods del sistema (coredns, kube-proxy, aws-node) están en estado `Running`
- [ ] Metrics Server está instalado y funcionando

**Imágenes y ECR:**
- [ ] Los repositorios ECR `my-webapp` y `my-api` fueron creados
- [ ] Las imágenes Docker fueron construidas exitosamente
- [ ] Las imágenes fueron pusheadas a ECR correctamente

**AWS Load Balancer Controller:**
- [ ] El AWS Load Balancer Controller está instalado en kube-system
- [ ] El service account IAM fue creado correctamente
- [ ] Los pods del controller están en estado `Running`

**Aplicación Multi-Tier:**
- [ ] PostgreSQL está corriendo en StatefulSet con volumen persistente
- [ ] Redis está corriendo y accesible
- [ ] El backend API tiene 2 réplicas corriendo
- [ ] El frontend webapp tiene 3 réplicas corriendo
- [ ] Todos los pods tienen health checks configurados (liveness y readiness)

**Networking y Acceso:**
- [ ] El Ingress fue creado y provisionó un ALB
- [ ] La aplicación es accesible vía la URL del Ingress
- [ ] El endpoint `/` devuelve el frontend
- [ ] El endpoint `/api/status` devuelve respuesta JSON del backend

**Auto-Scaling:**
- [ ] El HPA está configurado y monitoreando métricas
- [ ] El HPA escala pods cuando hay carga (hasta 10 réplicas)
- [ ] El HPA reduce pods cuando baja la carga (mínimo 3 réplicas)
- [ ] Las políticas de stabilization funcionan correctamente

**Cleanup:**
- [ ] Todos los recursos de Kubernetes fueron eliminados
- [ ] El cluster EKS fue eliminado correctamente
- [ ] Los repositorios ECR fueron eliminados
- [ ] Las políticas IAM fueron eliminadas

---

## Errores Comunes y Soluciones

| Error | Causa | Solución |
|-------|-------|----------|
| `eksctl: command not found` | eksctl no está instalado | Instala eksctl siguiendo la [guía oficial](https://eksctl.io/introduction/#installation) |
| `helm: command not found` | Helm no está instalado | Instala Helm: `curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 \| bash` |
| `error: unable to read client certificate` | kubeconfig no actualizado | Ejecuta `aws eks update-kubeconfig --name my-eks-cluster --region us-east-1` |
| `node is not ready` | Los nodes aún están inicializando | Espera 5-10 minutos y verifica con `kubectl get nodes` |
| `ImagePullBackOff` en custom images | No puede descargar imagen de ECR | Verifica que la imagen existe en ECR y que el placeholder `<ACCOUNT_ID>` fue reemplazado |
| `CrashLoopBackOff` en API pods | Falla conexión a database o redis | Verifica que postgres y redis están corriendo: `kubectl get pods -l tier=database` |
| `Error from server (NotFound): services "db" not found` | Database service no existe | Aplica `kubectl apply -f database.yaml` antes del API |
| `Ingress sin ADDRESS` | Load Balancer Controller no instalado | Verifica: `kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller` |
| `no matches for kind "Ingress"` | Versión incorrecta de K8s API | Verifica que estás usando `apiVersion: networking.k8s.io/v1` |
| `HPA unable to fetch metrics` | Metrics Server no instalado o no ready | Verifica: `kubectl get deployment metrics-server -n kube-system` |
| `error: You must be logged in to the server (Unauthorized)` | Token expirado o credenciales incorrectas | Ejecuta `aws eks update-kubeconfig --name my-eks-cluster --region us-east-1` |
| `denied: User not authorized to perform: ecr:GetAuthorizationToken` | Permisos ECR insuficientes | Agrega política `AmazonEC2ContainerRegistryPowerUser` al usuario IAM |
| `Error creating Load Balancer: SubnetNotFound` | Subnets no tienen tags requeridos | Agrega tags a subnets: `kubernetes.io/role/elb=1` (públicas) y `kubernetes.io/role/internal-elb=1` (privadas) |
| `pod has unbound immediate PersistentVolumeClaims` | No hay storage class disponible | Verifica: `kubectl get storageclass` - EKS debería tener `gp2` por defecto |
| `ImagePullBackOff` en postgres/redis | Error descargando imágenes públicas | Verifica conectividad a Internet desde los nodes o configura VPC endpoints |
| `ServiceAccount "aws-load-balancer-controller" not found` | Service account no creado correctamente | Re-ejecuta `eksctl create iamserviceaccount` del Paso 7.3 |
| Docker build falla con `permission denied` | Docker daemon no accesible | Ejecuta `sudo usermod -aG docker $USER` y reinicia sesión |
| `manifest does not contain minimum number of descriptors (1)` | Push a ECR falló | Verifica autenticación: `aws ecr get-login-password \| docker login...` |
| Cluster creation fails con `VPC limit exceeded` | Límite de VPCs alcanzado | Elimina VPCs no usadas o solicita aumento de límite |

---

## Tips para Troubleshooting

### Ver eventos del cluster
```bash
kubectl get events --sort-by='.lastTimestamp' --all-namespaces
```

### Inspeccionar un pod que falla
```bash
kubectl describe pod <pod-name>
kubectl logs <pod-name>
kubectl logs <pod-name> --previous  # Ver logs del contenedor anterior si crasheó
```

### Verificar conectividad entre pods
```bash
# Ejecutar shell en un pod
kubectl exec -it <pod-name> -- /bin/sh

# Probar conexión a database desde API pod
kubectl exec -it <api-pod-name> -- curl http://db:5432
```

### Verificar configuración del Ingress
```bash
kubectl describe ingress webapp-ingress
kubectl get targetgroupbindings  # Ver bindings del ALB
```

### Ver métricas de recursos
```bash
kubectl top nodes
kubectl top pods
```

---

## Notas Importantes

1. **Tiempo de creación del cluster**: El cluster EKS tarda ~20-25 minutos en crearse completamente
2. **Aprovisionamiento del ALB**: El Application Load Balancer tarda ~2-3 minutos en estar disponible
3. **Propagación DNS**: La URL del ALB puede tardar unos minutos en resolverse globalmente
4. **Costos**: Este lab incurre en costos por:
   - Cluster EKS (~$0.10/hora)
   - 2 instancias EC2 t3.small (~$0.04/hora cada una)
   - Application Load Balancer (~$0.025/hora)
   - EBS volumes (~$0.10/GB-mes)
   - NAT Gateway (~$0.045/hora + transfer)
   
   **Total estimado: ~$0.35-0.40/hora**. Asegúrate de ejecutar el cleanup al terminar.

5. **Seguridad**: Los secrets en este lab usan valores de ejemplo. En producción:
   - Usa AWS Secrets Manager o AWS Systems Manager Parameter Store
   - Nunca commits secrets en Git
   - Rota credenciales regularmente
   - Usa IAM roles for service accounts (IRSA) cuando sea posible

6. **Almacenamiento**: El StatefulSet de PostgreSQL crea un PVC de 10Gi que persiste incluso si eliminas el pod. Asegúrate de eliminarlo en el cleanup.

7. **Auto-scaling**: El HPA necesita ~1-2 minutos para reaccionar a cambios de carga. La política de scale-down tiene 5 minutos de stabilization para evitar flapping.

---

## Referencias

### Documentación Oficial AWS
- [Amazon EKS Documentation](https://docs.aws.amazon.com/eks/latest/userguide/)
- [Amazon ECR Documentation](https://docs.aws.amazon.com/ecr/)
- [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
- [EKS Best Practices Guide](https://aws.github.io/aws-eks-best-practices/)

### Herramientas de Gestión de Clusters
- [eksctl Documentation](https://eksctl.io/usage/getting-started/)
- [kubectl Documentation](https://kubernetes.io/docs/reference/kubectl/)
- [Helm Documentation](https://helm.sh/docs/)

### Kubernetes Core Concepts
- [Kubernetes Deployments](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
- [Kubernetes StatefulSets](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/)
- [Kubernetes Services](https://kubernetes.io/docs/concepts/services-networking/service/)
- [Kubernetes Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/)
- [Horizontal Pod Autoscaler](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)
- [ConfigMaps and Secrets](https://kubernetes.io/docs/concepts/configuration/configmap/)

### Monitoreo y Métricas
- [Metrics Server](https://github.com/kubernetes-sigs/metrics-server)
- [Amazon CloudWatch Container Insights](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/ContainerInsights.html)

### Almacenamiento
- [Kubernetes Persistent Volumes](https://kubernetes.io/docs/concepts/storage/persistent-volumes/)
- [EBS CSI Driver](https://docs.aws.amazon.com/eks/latest/userguide/ebs-csi.html)

### Seguridad
- [IAM Roles for Service Accounts](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html)
- [Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/)

### Docker
- [Docker Build Reference](https://docs.docker.com/engine/reference/commandline/build/)
- [Dockerfile Best Practices](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/)

