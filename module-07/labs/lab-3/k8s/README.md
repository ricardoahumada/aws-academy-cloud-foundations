# Manifiestos Kubernetes para Lab 7.3

Este directorio contiene los manifiestos de Kubernetes para desplegar una aplicación web multi-tier en Amazon EKS.

## Arquitectura

La aplicación consta de:
- **Frontend (webapp)**: Aplicación web que sirve contenido estático y llama a la API
- **Backend (api)**: API REST que procesa peticiones y consulta la base de datos
- **Database (postgres)**: Base de datos PostgreSQL para persistencia
- **Cache (redis)**: Cache Redis para mejorar el rendimiento

## Prerequisitos

Antes de aplicar estos manifiestos, asegúrate de tener:

1. **Cluster EKS creado** con eksctl
2. **AWS Load Balancer Controller instalado** (para Ingress)
3. **Metrics Server instalado** (para HPA)
4. **Imágenes Docker en ECR**:
   - `<ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/my-webapp:latest`
   - `<ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/my-api:latest`

## Orden de Aplicación

Aplica los manifiestos en el siguiente orden:

```bash
# 1. ConfigMap y Secrets (configuración)
kubectl apply -f configmap.yaml

# 2. Base de datos y cache (tier de datos)
kubectl apply -f database.yaml
kubectl apply -f redis.yaml

# Espera a que estén listos
kubectl wait --for=condition=ready pod -l app=postgres --timeout=180s
kubectl wait --for=condition=ready pod -l app=redis --timeout=180s

# 3. API backend (tier de aplicación)
kubectl apply -f api-deployment.yaml

# Espera a que esté listo
kubectl wait --for=condition=ready pod -l app=api --timeout=180s

# 4. Frontend webapp
kubectl apply -f deployment.yaml

# 5. Horizontal Pod Autoscaler
kubectl apply -f hpa.yaml

# 6. Ingress (punto de entrada)
kubectl apply -f ingress.yaml
```

## Reemplazar Placeholders

**IMPORTANTE**: Antes de aplicar los manifiestos, reemplaza `<ACCOUNT_ID>` con tu AWS Account ID:

```bash
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Linux/Mac
sed -i "s/<ACCOUNT_ID>/$AWS_ACCOUNT_ID/g" deployment.yaml api-deployment.yaml

# Windows PowerShell
(Get-Content deployment.yaml) -replace '<ACCOUNT_ID>', $env:AWS_ACCOUNT_ID | Set-Content deployment.yaml
(Get-Content api-deployment.yaml) -replace '<ACCOUNT_ID>', $env:AWS_ACCOUNT_ID | Set-Content api-deployment.yaml
```

## Actualizar Secrets

Edita `configmap.yaml` y actualiza los valores de los secrets antes de aplicar:

```yaml
stringData:
  DATABASE_PASSWORD: "tu-contraseña-segura"  # Cambia esto
  API_KEY: "tu-api-key-aqui"                  # Cambia esto
  JWT_SECRET: "tu-jwt-secret-aqui"            # Cambia esto
```

## Verificación

```bash
# Ver todos los recursos
kubectl get all

# Ver pods por tier
kubectl get pods -l tier=frontend
kubectl get pods -l tier=backend
kubectl get pods -l tier=database
kubectl get pods -l tier=cache

# Ver el Ingress y obtener la URL
kubectl get ingress webapp-ingress

# Verificar HPA
kubectl get hpa webapp-hpa
```

## Acceso a la Aplicación

Una vez que el Ingress esté listo (puede tomar 2-3 minutos), obtén la URL:

```bash
kubectl get ingress webapp-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

Accede a:
- **Frontend**: `http://<ingress-hostname>/`
- **API**: `http://<ingress-hostname>/api`

## Limpieza

Para eliminar todos los recursos:

```bash
kubectl delete -f ingress.yaml
kubectl delete -f hpa.yaml
kubectl delete -f deployment.yaml
kubectl delete -f api-deployment.yaml
kubectl delete -f redis.yaml
kubectl delete -f database.yaml
kubectl delete -f configmap.yaml
```

## Estructura de Archivos

| Archivo | Descripción |
|---------|-------------|
| `configmap.yaml` | ConfigMap con variables de entorno y Secret para credenciales |
| `database.yaml` | StatefulSet de PostgreSQL con volumen persistente |
| `redis.yaml` | Deployment de Redis para caching |
| `api-deployment.yaml` | Deployment del backend API + Service ClusterIP |
| `deployment.yaml` | Deployment del frontend webapp + Service LoadBalancer |
| `hpa.yaml` | HorizontalPodAutoscaler para auto-escalado basado en CPU/memoria |
| `ingress.yaml` | Ingress con AWS ALB para enrutamiento HTTP |

## Notas

- **Database**: Usa un StatefulSet con volumen persistente de 10Gi
- **Redis**: Configurado con política de eviction `allkeys-lru` y 256MB de memoria
- **Health Checks**: Todos los deployments incluyen liveness y readiness probes
- **Resource Limits**: Configurados para evitar consumo excesivo de recursos
- **Auto-scaling**: HPA configurado para escalar entre 3-10 réplicas basado en CPU (70%) y memoria (80%)
