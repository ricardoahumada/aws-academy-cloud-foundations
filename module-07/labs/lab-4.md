# Lab 7.4: Monitoreo de EKS con CloudWatch Container Insights (OPCIONAL)

## Objetivo

Configurar CloudWatch Container Insights en un cluster EKS para observar métricas de pods, servicios y el cluster completo, crear dashboards personalizados y configurar alarmas.

---

## Duración Estimada

**45 minutos**

---

## Prerrequisitos

- Cluster EKS `my-eks-cluster` creado (Lab 7.3)
- Namespace `webapp-namespace` con deployment `webapp` corriendo
- AWS CLI configurado (`aws sts get-caller-identity`)
- Permisos IAM para CloudWatch, EKS, IAM

---

## Recursos Necesarios

- Cluster EKS existente (`my-eks-cluster`)
- Namespace con aplicaciones corriendo
- Rol IAM para CloudWatch Agent (IRSA)

---

## Pasos

### Paso 1: Verificar el Cluster y Namespace

Antes de instalar Container Insights, verifica que tienes el cluster y aplicaciones corriendo.

1.1. Verifica que tu cluster existe y está listo:
```bash
aws eks list-clusters
```

1.2. Verifica que kubectl apunta al cluster correcto:
```bash
kubectl config current-context
kubectl get nodes
```

1.3. Verifica que tienes pods corriendo:
```bash
kubectl get pods -A
```

---

### Paso 2: Crear el Namespace para CloudWatch

CloudWatch Agent correrá en su propio namespace.

2.1. Crea el namespace:
```bash
kubectl create ns amazon-cloudwatch
```

2.2. Verifica:
```bash
kubectl get ns amazon-cloudwatch
```

---

### Paso 3: Configurar IAM para CloudWatch Agent (IRSA)

El CloudWatch Agent necesita permisos para escribir métricas y logs. Usarás IRSA (IAM Roles for Service Accounts).

3.1. Obtén el OIDC provider del cluster:
```bash
OIDC_PROVIDER=$(aws eks describe-cluster \
  --name my-eks-cluster \
  --query "cluster.identity.oidc.issuer" \
  --output text | sed 's|https://||')
echo "OIDC Provider: $OIDC_PROVIDER"
```

3.2. Crea el trust policy para el service account:
```bash
cat > cw-agent-trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::<account-id>:oidc-provider/${OIDC_PROVIDER}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "${OIDC_PROVIDER}:sub": "system:serviceaccount:amazon-cloudwatch:cwagent"
        }
      }
    }
  ]
}
EOF
```

3.3. Crea el rol IAM:
```bash
aws iam create-role \
  --role-name CWAgentEKSRole \
  --assume-role-policy-document file://cw-agent-trust-policy.json
```

3.4. Adjunta la política CloudWatchAgentServerPolicy:
```bash
aws iam attach-role-policy \
  --role-name CWAgentEKSRole \
  --policy-arn arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy
```

3.5. Anota el role ARN:
```bash
ROLE_ARN=$(aws iam get-role --role-name CWAgentEKSRole --query 'Role.Arn' --output text)
echo $ROLE_ARN
```

---

### Paso 4: Instalar CloudWatch Observability EKS Add-on

Desde 2024, la forma recomendada es usar el **EKS Add-on** `amazon-cloudwatch-observability`, que instala y gestiona automáticamente el CloudWatch Agent y Fluent Bit.

4.1. Instala el add-on usando el rol IAM creado en el Paso 3:
```bash
aws eks create-addon \
  --cluster-name my-eks-cluster \
  --addon-name amazon-cloudwatch-observability \
  --service-account-role-arn $ROLE_ARN \
  --region us-east-1
```

4.2. Verifica que el add-on está activo (puede tardar 2-3 minutos):
```bash
aws eks describe-addon \
  --cluster-name my-eks-cluster \
  --addon-name amazon-cloudwatch-observability \
  --region us-east-1 \
  --query 'addon.status'
```
Esperado: `"ACTIVE"`

4.3. Verifica que los pods del agent están corriendo:
```bash
kubectl get pods -n amazon-cloudwatch
```

Deberías ver pods de `cloudwatch-agent` (DaemonSet) y `fluent-bit` (DaemonSet) en cada nodo.

4.4. Verifica los logs del agent:
```bash
kubectl logs -n amazon-cloudwatch -l app.kubernetes.io/name=cloudwatch-agent
```

---

### Paso 5: Verificar Métricas en CloudWatch

Después de unos minutos (puede tomar hasta 5), las métricas aparecerán en CloudWatch.

5.1. Navega a **CloudWatch** en la consola de AWS.

5.2. Ve a **Metrics** > **All Metrics**.

5.3. Busca el namespace **ContainerInsights**.

5.4. Explora las métricas disponibles:
   - **ClusterLevel**: CPU, memory, network para el cluster
   - **NodeLevel**: Por nodo
   - **PodLevel**: Por pod (usa dimensión `PodName`, `K8sCluster`, `K8sNamespace`)

5.5. Lista las métricas por CLI:
```bash
aws cloudwatch list-metrics \
  --namespace ContainerInsights \
  --region us-east-1
```

5.6. Obtén estadísticas de CPU de los nodos del cluster:
```bash
aws cloudwatch get-metric-statistics \
  --namespace ContainerInsights \
  --metric-name node_cpu_utilization \
  --start-time $(date -u -d '10 minutes ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 60 \
  --statistics Average \
  --dimensions Name=ClusterName,Value=my-eks-cluster \
  --region us-east-1
```

---

### Paso 6: Crear Dashboard Personalizado

Crea un dashboard para monitorear tu aplicación en EKS.

6.1. En la consola de CloudWatch, ve a **Dashboards** > **Create dashboard**.

6.2. Nombre: `EKS-WebApp-Monitoring`.

6.3. Añade widgets:

   **Widget 1 - CPU de Nodos:**
   - Type: Line
   - Namespace: `ContainerInsights`
   - Metric: `node_cpu_utilization`
   - Dimensions: `ClusterName=my-eks-cluster`

   **Widget 2 - Memory de Nodos:**
   - Type: Line
   - Namespace: `ContainerInsights`
   - Metric: `node_memory_utilization`
   - Dimensions: `ClusterName=my-eks-cluster`

   **Widget 3 - Reinicios de Contenedores:**
   - Type: Number
   - Namespace: `ContainerInsights`
   - Metric: `pod_number_of_container_restarts`
   - Dimensions: `ClusterName=my-eks-cluster`

6.4. Guarda el dashboard.

6.5. Para crearlo por CLI, genera primero el JSON del dashboard:
```bash
cat > dashboard.json <<EOF
{
  "widgets": [
    {
      "type": "metric",
      "x": 0, "y": 0, "width": 12, "height": 6,
      "properties": {
        "title": "Node CPU Utilization",
        "period": 60,
        "stat": "Average",
        "metrics": [
          ["ContainerInsights", "node_cpu_utilization", "ClusterName", "my-eks-cluster"]
        ]
      }
    },
    {
      "type": "metric",
      "x": 12, "y": 0, "width": 12, "height": 6,
      "properties": {
        "title": "Node Memory Utilization",
        "period": 60,
        "stat": "Average",
        "metrics": [
          ["ContainerInsights", "node_memory_utilization", "ClusterName", "my-eks-cluster"]
        ]
      }
    },
    {
      "type": "metric",
      "x": 0, "y": 6, "width": 6, "height": 6,
      "properties": {
        "title": "Container Restarts",
        "period": 60,
        "stat": "Sum",
        "metrics": [
          ["ContainerInsights", "pod_number_of_container_restarts", "ClusterName", "my-eks-cluster"]
        ]
      }
    }
  ]
}
EOF
```

6.6. Crea el dashboard:
```bash
aws cloudwatch put-dashboard \
  --dashboard-name EKS-WebApp-Monitoring \
  --dashboard-body file://dashboard.json \
  --region us-east-1
```

6.7. Verifica que fue creado:
```bash
aws cloudwatch get-dashboard --dashboard-name EKS-WebApp-Monitoring --region us-east-1
```

---

### Paso 7: Configurar Alarmas

Crea alarmas para notificarte cuando los pods o el cluster tengan problemas.

7.1. **Alarma: CPU alto en el cluster (> 80% por 5 minutos):**

```bash
aws cloudwatch put-metric-alarm \
  --alarm-name EKS-HighCPU \
  --alarm-description "Node CPU usage above 80% for 5 minutes" \
  --metric-name node_cpu_utilization \
  --namespace ContainerInsights \
  --statistic Average \
  --period 300 \
  --threshold 80 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 1 \
  --dimensions Name=ClusterName,Value=my-eks-cluster \
  --alarm-actions <sns-topic-arn> \
  --region us-east-1
```

7.2. **Alarma: Reinicios de contenedores excesivos (> 5 en 5 minutos):**

```bash
aws cloudwatch put-metric-alarm \
  --alarm-name EKS-Pods-Failing \
  --alarm-description "Container restarts above 5 in 5 minutes" \
  --metric-name pod_number_of_container_restarts \
  --namespace ContainerInsights \
  --statistic Sum \
  --period 300 \
  --threshold 5 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 1 \
  --dimensions Name=ClusterName,Value=my-eks-cluster \
  --alarm-actions <sns-topic-arn> \
  --region us-east-1
```

7.3. **Alarma: Memory alto en nodos (> 80% por 5 minutos):**

```bash
aws cloudwatch put-metric-alarm \
  --alarm-name EKS-HighMemory \
  --alarm-description "Node memory usage above 80% for 5 minutes" \
  --metric-name node_memory_utilization \
  --namespace ContainerInsights \
  --statistic Average \
  --period 300 \
  --threshold 80 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 1 \
  --dimensions Name=ClusterName,Value=my-eks-cluster \
  --alarm-actions <sns-topic-arn> \
  --region us-east-1
```

7.4. Verifica las alarmas creadas:
```bash
aws cloudwatch describe-alarms \
  --alarm-names EKS-HighCPU EKS-Pods-Failing EKS-HighMemory \
  --region us-east-1
```

---

### Paso 8: Ver Logs en CloudWatch Logs

El CloudWatch Agent también envía logs de los contenedores.

8.1. Ve a **CloudWatch** > **Logs** > **Log groups**.

8.2. Busca el log group `/aws/containerinsights/my-eks-cluster/performance`.

8.3. Explora los streams de logs:
   - `node-level` — logs por nodo
   - `pod-level` — logs por pod

8.4. Filtra logs de un pod específico:
```bash
aws logs filter-log-events \
  --log-group-name "/aws/containerinsights/my-eks-cluster/performance" \
  --filter-pattern "nginx" \
  --region us-east-1
```

8.5. Ver logs de errores:
```bash
aws logs filter-log-events \
  --log-group-name "/aws/containerinsights/my-eks-cluster/application" \
  --filter-pattern "ERROR" \
  --region us-east-1
```

---

### Paso 9: Simular Carga y Observar Métricas

Genera tráfico para observar las métricas cambiar.

9.1. Obtén la IP del service:
```bash
kubectl get svc -n webapp-namespace
```

9.2. Ejecuta un generador de carga:
```bash
kubectl run load-generator \
  --image=busybox \
  -- /bin/sh -c "while true; do wget -q -O- http://<service-ip>; done" \
  -n webapp-namespace
```

9.3. Observa cómo las métricas de CPU cambian en el dashboard.

9.4. Elimina el generador de carga:
```bash
kubectl delete pod load-generator -n webapp-namespace
```

---

## Criterios de Verificación

Al finalizar este lab, debes poder confirmar que:

- [ ] El CloudWatch Agent (DaemonSet) está corriendo en todos los nodos del cluster
- [ ] El namespace `amazon-cloudwatch` fue creado
- [ ] Las métricas de ContainerInsights aparecen en CloudWatch Metrics
- [ ] El dashboard `EKS-WebApp-Monitoring` fue creado y muestra datos
- [ ] Las alarmas `EKS-HighCPU`, `EKS-Pods-Failing` y `EKS-HighMemory` fueron creadas
- [ ] Los logs de pods aparecen en `/aws/containerinsights/my-eks-cluster/performance`
- [ ] La dimensión `K8sNamespace`, `K8sPodName`, `K8sCluster` está presente en las métricas

---

## Errores Comunes y Soluciones

| Error | Causa | Solución |
|-------|-------|----------|
| Métricas no aparecen | El agent tarda hasta 5 minutos | Espera y verifica que los pods del agent están RUNNING |
| `NoSuchBucket` en logs | El log group no existe | Verifica que ContainerInsights está habilitado y el agente tiene permisos |
| IRSA no funciona | OIDC provider mal configurado | Verifica que el cluster tiene OIDC habilitado |
| Alarmas sin datos | Métricas no han sido recolectadas aún | Espera más tiempo o verifica que los pods generan métricas activamente |
| Add-on en estado DEGRADED | IRSA mal configurado o permisos insuficientes | Verifica el role ARN con `aws eks describe-addon --addon-name amazon-cloudwatch-observability` |

---

## Limpieza de Recursos

Para evitar costos innecesarios, elimina los recursos creados:

```bash
# Eliminar el dashboard
aws cloudwatch delete-dashboards \
  --dashboard-names EKS-WebApp-Monitoring \
  --region us-east-1

# Eliminar las alarmas
aws cloudwatch delete-alarms \
  --alarm-names EKS-HighCPU EKS-Pods-Failing EKS-HighMemory \
  --region us-east-1

# Desinstalar el EKS Add-on
aws eks delete-addon \
  --cluster-name my-eks-cluster \
  --addon-name amazon-cloudwatch-observability \
  --region us-east-1

# Eliminar el namespace (se elimina automáticamente con el add-on, pero por si acaso)
kubectl delete ns amazon-cloudwatch --ignore-not-found

# Eliminar el rol IAM (opcional)
aws iam detach-role-policy \
  --role-name CWAgentEKSRole \
  --policy-arn arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy
aws iam delete-role --role-name CWAgentEKSRole
```

---

## Referencias

- [CloudWatch Container Insights for EKS](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/ContainerInsights.html)
- [EKS CloudWatch Agent Installation](https://docs.aws.amazon.com/eks/latest/userguide/container-insights.html)
- [Container Insights Metrics](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/ContainerInsights-container-metrics.html)
- [Helm Chart for CloudWatch Agent](https://github.com/aws/eks-charts)
