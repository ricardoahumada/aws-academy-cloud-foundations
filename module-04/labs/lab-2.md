# Lab 4.2: Configuración de Route 53 con Routing Policies

## Objetivo

Configurar Amazon Route 53 con diferentes políticas de routing, health checks y failover para arquitecturas de alta disponibilidad. Al finalizar, comprenderás cómo implementar:

- Weighted routing (A/B testing)
- Latency-based routing
- Failover routing con health checks
- Geolocation routing

## Duración estimada

60 minutos

## Prerrequisitos

- Dominio propio (opcional, se puede usar subdomain de test)
- ALB creado en el Lab 4.1 (o crear un ALB simple)
- S3 bucket configurado como static website hosting (para backup en failover)
- AWS CLI configurado con credenciales apropiadas

## Arquitectura objetivo

```
┌────────────────────────────────────────────────────────────────────┐
│                        Route 53                                    │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌────────────┐ │
│  │  Weighted   │  │  Latency    │  │   Failover  │  │ Geolocation│ │
│  │  (A/B)      │  │  Routing    │  │  + Health   │  │ Routing    │ │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘  └───────┬────┘ │
└─────────┼────────────────┼────────────────┼─────────────────┼──────┘
          │                │                │                 │
    ┌─────▼─────┐    ┌─────▼──────┐    ┌────▼───────┐   ┌─────▼─────┐
    │  v1 (80%) │    │  ALB-USE   │    │  Primary   │   │  ALB-US   │
    │  v2 (20%) │    │  ALB-EUC   │    │  ALB       │   │  ALB-EU   │
    └───────────┘    └────────────┘    └─────┬──────┘   └───────────┘
                                             │
                                      ┌──────▼────┐
                                      │  Backup   │
                                      │  S3       │
                                      └───────────┘
```

---

## Paso 1: Crear Hosted Zone

### 1.1 Crear Public Hosted Zone

1. En la consola de AWS, ir a **Services** > **Route 53** > **Hosted zones**
2. Clic en **Create hosted zone**
3. Configurar:
   - **Domain name**: `mi-dominio.example.com` (reemplazar con tu dominio real)
   - **Type**: **Public hosted zone**
   - **Description**: `Hosted zone for production domain`
4. Clic en **Create**

> **Nota:** Si no tienes un dominio propio, puedes usar una **Private Hosted Zone** para pruebas internas.

### 1.2 Delegar DNS al registrado

1. En la hosted zone recién creada, copiar los **NS records** (4 servidores de nombres)
2. En el portal de tu registrador de dominio, actualizar los servidores de nombres:
   - Eliminar los servidores de nombres actuales
   - Agregar los 4 NS records de Route 53
3. **Nota**: Los cambios de DNS pueden tardar hasta 48 horas en propagarse globalmente

### 1.3 Verificar configuración básica

```bash
# Verificar que la hosted zone existe
aws route53 list-hosted-zones

# Verificar delegacion DNS
nslookup mi-dominio.example.com
```

---

## Paso 2: Crear Health Checks

### 2.1 Crear Health Check para ALB primario

1. En Route 53, ir a **Health checks** > **Create health check**
2. Configurar:
   - **Name**: `hc-primary-web`
   - **What to monitor**: **Endpoint**
   - **Specify endpoint**: **Yes**
   - **Domain name**: `web.mi-dominio.example.com` (usar el DNS del ALB real o crear un CNAME)
   - **Protocol**: **HTTP**
   - **Port**: **80**
   - **Path**: `/index.html`

> **Nota:** En este lab se usa HTTP/80 porque no hemos configurado un certificado ACM. En producción se recomienda HTTPS/443 con un certificado emitido por ACM.
3. En **Advanced configuration**:
   - **Request interval**: **30 seconds** (Standard)
   - **Failure threshold**: **3**
   - **Data threshold**: (dejar por defecto)
4. Clic en **Create**

### 2.2 Crear Health Check para región secundaria (opcional)

1. Crear otro health check:
   - **Name**: `hc-backup-s3`
   - **What to monitor**: **Endpoint**
   - **Domain name**: el S3 static website endpoint
   - **Protocol**: **HTTP**
   - **Port**: 80
   - **Path**: `index.html`

### 2.3 Verificar Health Checks

1. Esperar 30-60 segundos
2. Verificar que el estado sea **Healthy**
3. Si aparece **Healthy**, el health check está funcionando correctamente

---

## Paso 3: Configurar Weighted Routing (A/B Testing)

### 3.1 Crear record para versión 1 (80% del tráfico)

> **Importante:** Para recursos AWS como ALBs, siempre usar **Alias records** (no registros A con IPs directas). Las IPs de los ALBs son dinámicas y pueden cambiar.

1. En la hosted zone, clic en **Create record**
2. Configurar:
   - **Record name**: `ab.mi-dominio.example.com`
   - **Record type**: **A**
   - Activar el toggle **Alias**
   - **Route traffic to**: **Alias to Application and Classic Load Balancer**
   - **Region**: us-east-1
   - **Load balancer**: seleccionar el DNS del ALB v1
   - **Routing policy**: **Weighted**
   - **Weight**: **80**
   - **Set ID**: `version-1`
   - **Evaluate target health**: **Yes**
3. Clic en **Create records**

### 3.2 Crear record para versión 2 (20% del tráfico)

1. En la misma hosted zone, clic en **Create record**
2. Configurar:
   - **Record name**: `ab.mi-dominio.example.com` (mismo nombre)
   - **Record type**: **A**
   - Activar el toggle **Alias**
   - **Route traffic to**: **Alias to Application and Classic Load Balancer**
   - **Region**: us-east-1
   - **Load balancer**: seleccionar el DNS del ALB v2
   - **Routing policy**: **Weighted**
   - **Weight**: **20**
   - **Set ID**: `version-2`
   - **Evaluate target health**: **Yes**
3. Clic en **Create records**

> **Nota**: En caso de usar private hosted zone, ejecutar antes de la verificación los siguientes comandos para habilitar DNS en la VPC y asociar la hosted zone:
```bash
# Habilitar enableDnsSupport
aws ec2 modify-vpc-attribute --vpc-id <vpc-id> --enable-dns-support "{\"Value\":true}"

# Habilitar enableDnsHostnames
aws ec2 modify-vpc-attribute --vpc-id <vpc-id> --enable-dns-hostnames "{\"Value\":true}"


# Verificar
aws ec2 describe-vpc-attribute --vpc-id <vpc-id> --attribute enableDnsSupport
aws ec2 describe-vpc-attribute --vpc-id <vpc-id> --attribute enableDnsHostnames

# Asociar HZ a VPC
aws route53 associate-vpc-with-hosted-zone \
  --hosted-zone-id <HZ-id> \
  --vpc VPCRegion=us-east-1,VPCId=vpc-086cc4594670150d4
```

### 3.3 Verificar Weighted routing
> **Nota**: En caso de usar private hosted zone, ejecutar desde una instancia en la misma VPC para resolver el DNS correctamente.

```bash
# Hacer múltiples requests y contar respuestas
for i in {1..10}; do
  curl -s -o /dev/null -w "%{http_code} " http://ab.mi-dominio.example.com
  sleep 1
done
echo ""

# Verificar en CloudWatch los health check metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/Route53 \
  --metric-name HealthCheckStatus \
  --dimensions Name=HealthCheckId,Value=<health-check-id> \
  --start-time $(date -u -d "12 hours ago" +"%Y-%m-%dT%H:%M:%SZ") \
  --end-time $(date -u +"%Y-%m-%dT%H:%M:%SZ") \
  --period 300 \
  --statistics Average
```

---

## Paso 4: Configurar Latency-Based Routing

### 4.1 Crear record para región us-east-1

1. En la hosted zone, clic en **Create record**
2. Configurar:
   - **Record name**: `latency.mi-dominio.example.com`
   - **Record type**: **A**
   - Activar el toggle **Alias**
   - **Route traffic to**: **Alias to Application and Classic Load Balancer**
   - **Region**: **us-east-1**
   - **Load balancer**: seleccionar el DNS del ALB en us-east-1
   - **Routing policy**: **Latency**
   - **Evaluate target health**: **Yes**
3. Clic en **Create records**

### 4.2 Crear record para región eu-west-1

1. Crear otro record con:
   - **Record name**: `latency.mi-dominio.example.com` (mismo nombre)
   - **Record type**: **A**
   - Activar el toggle **Alias**
   - **Route traffic to**: **Alias to Application and Classic Load Balancer**
   - **Region**: **eu-west-1**
   - **Load balancer**: seleccionar el DNS del ALB en eu-west-1
   - **Routing policy**: **Latency**
   - **Evaluate target health**: **Yes**

### 4.3 Verificar Latency routing

```bash
# Desde diferentes ubicaciones, hacer requests
# AWS Route 53 automáticamente routing al más cercano

# En us-east-1 (Virginia)
curl -s http://latency.mi-dominio.example.com

# En eu-west-1 (Irlanda)  
curl -s http://latency.mi-dominio.example.com
```

---

## Paso 5: Configurar Failover Routing

### 5.1 Crear record primario (con health check)

1. En la hosted zone, clic en **Create record**
2. Configurar:
   - **Record name**: `www.mi-dominio.example.com`
   - **Record type**: **A**
   - Activar el toggle **Alias**
   - **Route traffic to**: **Alias to Application and Classic Load Balancer**
   - **Region**: us-east-1
   - **Load balancer**: seleccionar el DNS del ALB primario
   - **Routing policy**: **Failover**
   - **Failover record type**: **Primary**
   - **Associate with health check**: **Yes** > seleccionar `hc-primary-web`
   - **Evaluate target health**: **Yes**
3. Clic en **Create records**

### 5.2 Crear record secundario (backup S3)

1. Crear otro record con:
   - **Record name**: `www.mi-dominio.example.com` (mismo nombre)
   - **Record type**: **A**
   - Activar el toggle **Alias**
   - **Route traffic to**: **Alias to S3 website endpoint**
   - **Region**: us-east-1
   - **S3 bucket**: seleccionar el bucket con static website hosting habilitado
   - **Routing policy**: **Failover**
   - **Failover record type**: **Secondary**
   - **Evaluate target health**: **No**

> **Nota:** El bucket S3 debe tener static website hosting habilitado y el nombre del bucket debe coincidir exactamente con el record name (p.ej. `www.mi-dominio.example.com`).

### 5.3 Verificar Failover

**Prueba de funcionamiento normal:**
```bash
curl -s -I http://www.mi-dominio.example.com
# Debe mostrar headers del ALB primario
```

**Simular fallo del primario:**
1. Ir a **Route 53** > **Health checks**
2. Forzar fallo del health check `hc-primary-web` editando su path:
   - Seleccionar el health check > **Actions** > **Edit health check**
   - Cambiar **Path** de `/index.html` a `/fallo-test-404`
   - Guardar
3. Esperar 60-90 segundos (interval × failure threshold)
4. Hacer request nuevamente:
```bash
curl -s -I http://www.mi-dominio.example.com
# Ahora debe mostrar headers del S3 static website
```

5. **Restaurar el health check** después de la prueba:
   - Volver a editar el health check y cambiar **Path** de nuevo a `/index.html`

---

## Paso 6: Configurar Geolocation Routing

### 6.1 Crear record para Estados Unidos

1. En la hosted zone, clic en **Create record**
2. Configurar:
   - **Record name**: `geo.mi-dominio.example.com`
   - **Record type**: **A**
   - Activar el toggle **Alias**
   - **Route traffic to**: **Alias to Application and Classic Load Balancer**
   - **Region**: us-east-1
   - **Load balancer**: seleccionar el DNS del ALB en us-east-1
   - **Routing policy**: **Geolocation**
   - **Location**: **United States**
   - **Evaluate target health**: **Yes**
3. Clic en **Create records**

### 6.2 Crear record para Europa

1. Crear otro record con:
   - **Record name**: `geo.mi-dominio.example.com`
   - **Record type**: **A**
   - Activar el toggle **Alias**
   - **Route traffic to**: **Alias to Application and Classic Load Balancer**
   - **Region**: eu-west-1
   - **Load balancer**: seleccionar el DNS del ALB en eu-west-1
   - **Routing policy**: **Geolocation**
   - **Location**: **Europe**
   - **Evaluate target health**: **Yes**

### 6.3 Crear record Default (para usuarios de otras regiones)

1. Crear otro record con:
   - **Record name**: `geo.mi-dominio.example.com`
   - **Record type**: **A**
   - Activar el toggle **Alias**
   - **Route traffic to**: **Alias to Application and Classic Load Balancer**
   - **Region**: us-east-1
   - **Load balancer**: seleccionar el DNS del ALB por defecto
   - **Routing policy**: **Geolocation**
   - **Location**: **Default**
   - **Evaluate target health**: **Yes**

> **Nota**: Los registros Alias NO admiten TTL personalizado; AWS lo gestiona automáticamente.

### 6.4 Verificar Geolocation routing

```bash
# Usar herramientas online de geolocation DNS lookup
# O simular con --resolve flag de curl

# Forzar resolución a diferentes IPs
curl --resolve geo.mi-dominio.example.com:80:<US-IP> http://geo.mi-dominio.example.com
curl --resolve geo.mi-dominio.example.com:80:<EU-IP> http://geo.mi-dominio.example.com
```

---

## Paso 7: Verificar Configuración Completa

### 7.1 Listar todos los records creados

```bash
aws route53 list-resource-record-sets \
  --hosted-zone-id <hosted-zone-id> \
  --query 'ResourceRecordSets[*].{Name:Name,Type:Type,TTL:TTL}' \
  --output table
```

### 7.2 Verificar health checks en CloudWatch

```bash
# Ver métricas de todos los health checks
aws cloudwatch list-metrics \
  --namespace AWS/Route53 \
  --metric-name HealthCheckStatus

# Obtener estadísticas de un health check específico
aws cloudwatch get-metric-statistics \
  --namespace AWS/Route53 \
  --metric-name HealthCheckStatus \
  --dimensions Name=HealthCheckId,Value=<health-check-id> \
  --start-time $(date -u -d "12 hours ago" +"%Y-%m-%dT%H:%M:%SZ") \
  --end-time $(date -u +"%Y-%m-%dT%H:%M:%SZ") \
  --period 300 \
  --statistics Maximum,Minimum
```

### 7.3 Probar cada política de routing

```bash
# 1. Weighted (A/B) - verificar distribución
for i in {1..100}; do
  curl -s -o /dev/null -w "%{time_total} " http://ab.mi-dominio.example.com 2>/dev/null
done | awk '{sum+=$1; count++} END {print "Average response time:", sum/count "ms"}'

# 2. Failover - simular primaria caída
# Deshabilitar health check primario, verificar respuesta secundaria

# 3. Geolocation - probar desde diferentes IPs de origen
# (requiere herramientas externas de testing)

# 4. Latency - verificar menor latencia a región más cercana
ping -c 10 latency.mi-dominio.example.com
```

---

## Verificación Final

Al completar este lab, debes ser capaz de:

- [ ] Crear una Public Hosted Zone en Route 53
- [ ] Configurar Health Checks para monitorear endpoints
- [ ] Implementar Weighted routing para A/B testing
- [ ] Implementar Latency-based routing multi-región
- [ ] Implementar Failover routing con health check automático
- [ ] Implementar Geolocation routing por país/continente
- [ ] Verificar el comportamiento de cada política de routing

---

## Errores Comunes y Soluciones

| Error | Causa | Solución |
|-------|-------|----------|
| Health check muestra `Healthy` pero request falla | Health check funciona pero el sitio tiene problemas | Revisar logs del ALB y health check path |
| Weighted routing no distribuye como esperado | DNS caching agresivo | Reducir TTL a 60 segundos o menos |
| Failover no cambia al secundario | Health check no está asociado correctamente | Verificar que el health check ID está asociado al record primario |
| NS records no propagados | Cambios en el registrador aún en proceso | Esperar hasta 48 horas o verificar con `dig NS` |
| Geolocation retorna record incorrecto | Location está en Default en lugar de país específico | Crear record Default explícito como fallback |
| Latency routing selecciona región incorrecta | Latencia real no corresponde a la esperada | Revisar métricas de latencia en CloudWatch |

---

## Limpieza de Recursos

Para eliminar los recursos creados:

```bash
# Eliminar records de la hosted zone (EXCEPTO NS y SOA, que son obligatorios)
# IMPORTANTE: la API de Route 53 requiere el ResourceRecordSet completo (TTL + valores)
# para eliminar un registro. El método más seguro es usar la consola:
#   Route 53 > Hosted zones > <zona> > seleccionar cada record > Delete

# Para registros Alias creados en este lab, hacerlo desde la consola:
#   - ab.mi-dominio.example.com (Weighted x2)
#   - latency.mi-dominio.example.com (Latency x2)
#   - www.mi-dominio.example.com (Failover x2)
#   - geo.mi-dominio.example.com (Geolocation x3)

# Eliminar health checks
aws route53 delete-health-check --health-check-id <health-check-id-1>
aws route53 delete-health-check --health-check-id <health-check-id-2>

# No eliminar la hosted zone si aún la usas para otros propósitos
```
