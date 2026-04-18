# Lab 7.3: Configurar Cluster EKS Básico con kubectl

## Objetivo

Crear un cluster Amazon EKS usando eksctl y desplegar una aplicación de ejemplo usando kubectl, configurando deployments, services y verificando la conectividad.

---

## Duración Estimada

**45 minutos**

---

## Prerrequisitos

- CLI de AWS configurado (`aws sts get-caller-identity`)
- `eksctl` instalado ([instalación oficial](https://eksctl.io/introduction/#installation))
- `kubectl` instalado ([instalación oficial](https://kubernetes.io/docs/tasks/tools/))
- IAM role con permisos para crear clusters EKS, node groups, y recursos de red
- AWS VPC con subnets públicas y privadas en al menos 2 AZs

---

## Recursos Necesarios

- VPC: `10.0.0.0/16` con subnets en `us-east-1a` y `us-east-1b`
- Key pair para las instancias EC2 (opcional)
- IAM role para los nodes del cluster

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

Los nodes de EKS necesitan un IAM role con políticas mínimas.

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

3.1. Crea el archivo de configuración `cluster.yaml`:
   ```bash
   cat > cluster.yaml <<EOF
   apiVersion: eksctl.io/v1alpha5
   kind: ClusterConfig

   metadata:
     name: my-eks-cluster
     region: us-east-1
     version: "1.32"

   vpc:
     cidr: 10.0.0.0/16
     nat:
       gateway: HighlyAvailable

   managedNodeGroups:
     - name: workers
       instanceType: t3.medium
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
       version: latest
     - name: coredns
       version: latest
     - name: kube-proxy
       version: latest
   EOF
   ```

3.2. Crea el cluster:
   ```bash
   eksctl create cluster -f cluster.yaml
   ```

   Este comando tomará aproximadamente 20-25 minutos.

3.3. Durante la creación, eksctl mostrará progreso como:
   ```
   [ℹ]  eksctl version 0.100.0
   [ℹ]  using region us-east-1
   [✓]  EKS cluster "my-eks-cluster" in "us-east-1" region
   [ℹ]  Nodegroup "workers" is ready
   ```

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

### Paso 5: Crear Namespace para la Aplicación (Opcional)

5.1. Crea un namespace para organizar los recursos:
   ```bash
   kubectl create namespace webapp-namespace
   ```

5.2. Verifica que fue creado:
   ```bash
   kubectl get namespaces
   ```

---

### Paso 6: Crear Deployment

6.1. Crea el archivo `deployment.yaml`:
   ```bash
   cat > deployment.yaml <<EOF
   apiVersion: apps/v1
   kind: Deployment
   metadata:
     name: webapp
     labels:
       app: webapp
       environment: development
   spec:
     replicas: 2
     selector:
       matchLabels:
         app: webapp
     template:
       metadata:
         labels:
           app: webapp
           environment: development
       spec:
         containers:
         - name: webapp
           image: nginx:latest
           ports:
           - containerPort: 80
             name: http
           resources:
             limits:
               memory: "128Mi"
               cpu: "250m"
             requests:
               memory: "64Mi"
               cpu: "125m"
           livenessProbe:
             httpGet:
               path: /
               port: 80
             initialDelaySeconds: 10
             periodSeconds: 10
           readinessProbe:
             httpGet:
               path: /
               port: 80
             initialDelaySeconds: 5
             periodSeconds: 5
   EOF
   ```

6.2. Aplica el deployment:
   ```bash
   kubectl apply -f deployment.yaml
   ```

6.3. Verifica el deployment:
   ```bash
   kubectl get deployments -n default
   kubectl describe deployment webapp
   ```

6.4. Verifica los pods:
   ```bash
   kubectl get pods -l app=webapp
   ```

6.5. Revisa los logs de un pod:
   ```bash
   kubectl logs -l app=webapp
   ```

---

### Paso 7: Crear Service LoadBalancer

7.1. Crea el archivo `service.yaml`:
   ```bash
   cat > service.yaml <<EOF
   apiVersion: v1
   kind: Service
   metadata:
     name: webapp-service
     labels:
       app: webapp
   spec:
     type: LoadBalancer
     selector:
       app: webapp
     ports:
     - port: 80
       targetPort: 80
       protocol: TCP
       name: http
   EOF
   ```

7.2. Aplica el service:
   ```bash
   kubectl apply -f service.yaml
   ```

7.3. Verifica el service:
   ```bash
   kubectl get services
   ```
   El EXTERNAL-IP puede tomar 2-3 minutos en aparecer.

7.4. Describe el service para ver detalles:
   ```bash
   kubectl describe service webapp-service
   ```

---

### Paso 8: Verificar el Acceso a la Aplicación

8.1. Espera a que el LoadBalancer aprovisione la IP externa:
   ```bash
   kubectl get services -w
   ```
   Presiona Ctrl+C para salir del modo watch.

8.2. Obtén la URL del service:
   ```bash
   kubectl get service webapp-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
   ```
   O si es IP:
   ```bash
   kubectl get service webapp-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
   ```

8.3. Prueba el acceso:
   ```bash
   curl http://<EXTERNAL-IP>
   ```
   Deberías ver la página de bienvenida de nginx.

8.4. Verifica que hay 2 pods respondiendo:
   ```bash
   kubectl get pods -l app=webapp -o wide
   ```

---

### Paso 9: Escalar el Deployment

9.1. Escala a 4 réplicas:
   ```bash
   kubectl scale deployment webapp --replicas=4
   ```

9.2. Verifica:
   ```bash
   kubectl get pods -l app=webapp
   ```

9.3. Escala de vuelta a 2:
   ```bash
   kubectl scale deployment webapp --replicas=2
   ```

---

### Paso 10: Cleanup - Eliminar Recursos

Es importante limpiar los recursos para evitar costos innecesarios.

10.1. Elimina el service:
   ```bash
   kubectl delete service webapp-service
   ```

10.2. Elimina el deployment:
   ```bash
   kubectl delete deployment webapp
   ```

10.3. Elimina el namespace (si lo creaste):
   ```bash
   kubectl delete namespace webapp-namespace
   ```

10.4. Elimina el cluster EKS:
   ```bash
   eksctl delete cluster -f cluster.yaml
   ```
   Esto eliminará el cluster, los node groups, y los recursos asociados.

10.5. Verifica que los recursos fueron eliminados:
   ```bash
   aws eks list-clusters
   ```

---

## Criterios de Verificación

Al finalizar este lab, debes poder confirmar que:

- [ ] El cluster EKS `my-eks-cluster` fue creado exitosamente
- [ ] kubectl está configurado correctamente y puede comunicarse con el cluster
- [ ] Los nodes del node group están en estado `Ready`
- [ ] Los pods del sistema (coredns, kube-proxy, aws-node) están en estado `Running`
- [ ] El deployment `webapp` fue creado con 2 réplicas
- [ ] El service `webapp-service` de tipo LoadBalancer fue creado
- [ ] La aplicación nginx es accesible via la URL del LoadBalancer
- [ ] Los health checks (liveness y readiness) están configurados
- [ ] El scaling del deployment funciona correctamente
- [ ] Los recursos fueron eliminados exitosamente con `eksctl delete cluster`

---

## Errores Comunes y Soluciones

| Error | Causa | Solución |
|-------|-------|----------|
| `eksctl: command not found` | eksctl no está instalado | Instala eksctl siguiendo la guía oficial |
| `error: unable to read client certificate` | kubeconfig no actualizado | Ejecuta `aws eks update-kubeconfig --name my-eks-cluster` |
| `node is not ready` | Los nodes aún están inicializando | Espera 5-10 minutos y verifica con `kubectl get nodes` |
| `ImagePullBackOff` | No puede descargar la imagen nginx | Verifica que los nodes tienen acceso a Internet o usa un VPC endpoint para ECR |
| `CrashLoopBackOff` | La aplicación falla al iniciar | Revisa los logs con `kubectl logs <pod-name>` |
| `LoadBalancer sin EXTERNAL-IP` | El LoadBalancer tarda en aprovisionar | Espera hasta 5 minutos, verifica los security groups |
| `No nodes available for deployment` | No hay nodes disponibles | Verifica que el node group está activo con `kubectl get nodes` |
| `Unauthorized` error en AWS CLI | Credenciales expiradas o mal configuradas | Ejecuta `aws configure` o verifica el perfil de credenciales |

---

## Referencias

- [Amazon EKS Documentation](https://docs.aws.amazon.com/eks/latest/userguide/)
- [eksctl Documentation](https://eksctl.io/usage/getting-started/)
- [kubectl Documentation](https://kubernetes.io/docs/reference/kubectl/)
- [Kubernetes Deployment](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
- [Kubernetes Service](https://kubernetes.io/docs/concepts/services-networking/service/)
