# Lab 3.3: Configuración de CloudTrail y CloudWatch

## Objetivo

Configurar CloudTrail para realizar logging centralizado de llamadas API, integrar con CloudWatch Logs para almacenamiento y análisis de logs, crear metric filters para detectar eventos específicos, y configurar alarmas para notificaciones de seguridad.

## Duración estimada

60 minutos

## Prerrequisitos

- Cuenta AWS con permisos de administrador o permisos específicos para CloudTrail y CloudWatch
- AWS CLI instalado y configurado
- Acceso a un email válido para recibir notificaciones SNS (opcional para alarmas)

## Recursos

- Tiempo aproximado: 60 minutos
- Costos: CloudTrail tiene costo de $2.00 por 100,000 eventos enTrail (el primer trail es gratis en algunas regiones)

---

## Pasos

### Paso 1: Crear Trail con Integración CloudWatch

1. En la consola AWS, navegar a **CloudTrail** > **Trails** > **Create trail**

2. Configurar el trail:
   - **Trail name**: `security-audit-trail`
   - **Apply trail to all regions**: Yes (recomendado)
   - **Management events**: Enable with All (para capturar operaciones de gestión)
   - **Data events**: Dejar deshabilitado por ahora (genera muchos eventos)
   - **Insights events**: Disable (costo adicional)

3. En **Storage location**:
   - **Create a new S3 bucket**: Yes
   - **S3 bucket**: `cloudtrail-logs-<nombre-unico>` (nombre debe ser único globalmente)

4. En **Additional configuration**:
   - **Log file validation**: Enable (importante para tamper-evidence)
   - **CloudWatch Logs**: Enable
     - **Log group**: Create new
     - **Log group name**: `/aws/cloudtrail/security-audit`
     - **Trail log event**: New/Existing role (crear nuevo rol)

5. Create trail

---

### Paso 2: Verificar que CloudTrail Está Registrando Eventos

1. Ir a **CloudTrail** > **Event history**

2. En el panel de filtros:
   - **Lookup attributes**: Event source
   - Valor: `ec2.amazonaws.com`
   - **Time range**: Last 15 minutes

3. Hacer clic en **Lookup**

4. Verificar que aparecen eventos como:
   - `RunInstances`
   - `DescribeInstances`
   - `DescribeSecurityGroups`

5. Probar generando algunos eventos intencionales:
   - Desde la consola, crear un bucket S3 nuevo
   - Crear un volumen EBS

6. Refrescar **Event history** y verificar que los nuevos eventos aparecen

---

### Paso 3: Explorar CloudWatch Logs

1. En la consola AWS, navegar a **CloudWatch** > **Logs** > **Log groups**

2. Encontrar el log group: `/aws/cloudtrail/security-audit`

3. Hacer clic en el log group para ver los **Log streams**

4. Seleccionar un log stream para ver los eventos recientes

5. Explorar la estructura del log:
   - `timestamp`: Hora del evento
   - `awsRegion`: Región donde ocurrió
   - `eventSource`: Servicio (ej: iam.amazonaws.com)
   - `eventName`: Nombre de la operación (ej: CreateUser)
   - `userIdentity`: Información del usuario que realizó la acción
   - `requestParameters`: Parámetros de la solicitud
   - `responseElements`: Respuesta de la API

---

### Paso 4: Crear Metric Filter para Console Login

1. En CloudWatch > **Logs**, seleccionar el grupo `/aws/cloudtrail/security-audit`

2. Hacer clic en **Actions** > **Create metric filter**

3. En **Define pattern**:
   - **Filter pattern**:
   ```
   { $.eventName = "ConsoleLogin" }
   ```
   - **Select log data to test**: Elegir el log stream

4. Hacer clic en **Next**

5. En **Assign metric**:
   - **Filter name**: `ConsoleLoginFilter`
   - **Metric namespace**: `CloudTrailMetrics`
   - **Metric name**: `ConsoleLoginCount`
   - **Metric value**: `1`
   - **Default value**: (dejar vacío)

6. Create metric filter

---

### Paso 5: Crear Alarma para Console Login

1. En CloudWatch > **Logs**, seleccionar el grupo `/aws/cloudtrail/security-audit`

2. Ir a la pestaña **Metric filters**

3. Encontrar el filter `ConsoleLoginFilter` y hacer clic en su nombre

4. Hacer clic en **Create alarm**

5. Configurar la alarma:
   - **Metric**: Confirmar namespace `CloudTrailMetrics`, metric `ConsoleLoginCount`
   - **Period**: 1 minute
   - **Statistic**: Sum
   - **Threshold**:
     - **Conditions**: Greater than
     - **Than**: 5
   - **Treat missing data as**: notBreaching

6. En **Notification**:
   - **Alarm state trigger**: In alarm
   - **Select an SNS topic**: Create new topic
   - **Email endpoint**: Tu email válido
   - Topic name: `cloudtrail-alerts`

7. Create alarm

8. **Confirmar suscripción**: Revisar el email y hacer clic en el enlace de confirmación SNS

---

### Paso 6: Generar Eventos de Prueba

1. **Generar evento ConsoleLogin**:
   - Cerrar la sesión actual de la consola AWS
   - Volver a iniciar sesión (esto genera un evento ConsoleLogin)

2. **Generar eventos API**:
```bash
# Ejecutar comandos para generar eventos
aws ec2 describe-instances --region us-east-1
aws s3 ls
aws iam list-users
```

3. **Esperar 2-3 minutos** para que los eventos aparezcan en CloudWatch

4. Ir a **CloudWatch** > **Metrics** > **All metrics**

5. Buscar el namespace `CloudTrailMetrics`

6. Verificar que aparece la métrica `ConsoleLoginCount`

7. Hacer clic en la métrica para ver el gráfico en tiempo real

---

### Paso 7: Explorar CloudTrail Insights (Opcional - Demostración)

**Nota**: Los eventos de Insights requieren 24+ horas para mostrar anomalías. Esta sección es demostrativa.

1. En CloudTrail > **Insights**

2. Verificar si hay algún insight disponible (probablemente none aún)

3. Hacer clic en **Enable Insights** (opcional, genera costo adicional)

4. Revisar la documentación:
   - Insights detecta anomalías en patrones de escritura
   - Ejemplo: Muchos más `Delete*` events de lo normal
   - Ejemplo: Un usuario que normalmente solo lee empieza a crear recursos

5. Discutir: En producción, se habilitaría Insights y se revisaría periódicamente

---

### Paso 8: Investigar Eventos de Seguridad

1. En CloudTrail Event history, buscar eventos sensibles:

   - **IAM Policy changes**:
     - Filter: **Lookup attributes** → Event source = `iam.amazonaws.com`
     - Revisar manualmente eventos cuyo nombre contenga `Policy` (ej: `CreatePolicy`, `AttachUserPolicy`)

   - **S3 Bucket policy changes**:
     - Filter: **Lookup attributes** → Event source = `s3.amazonaws.com`
     - Revisar eventos como `PutBucketPolicy`, `DeleteBucketPolicy`

   - **Errores de acceso** (requiere CloudWatch Logs Insights):
     - Event history **no permite filtrar por `errorCode`** en la UI
     - Ir a **CloudWatch** > **Logs Insights**, seleccionar el log group del trail y ejecutar:
     ```
     fields @timestamp, eventName, errorCode, userIdentity.arn
     | filter errorCode = "AccessDenied" or errorCode = "InvalidAccessKeyId"
     | sort @timestamp desc
     | limit 20
     ```

2. Seleccionar un evento y revisar:
   - **User identity**: Quién lo hizo
   - **IP address**: Desde dónde (en responseElements si está disponible)
   - **Time**: Cuándo ocurrió
   - **Resources**: Qué recursos afectó

3. Crear un log filter para errores de acceso:
   - Pattern: `{ $.errorCode = "AccessDenied" }`
   - Metric: `AccessDeniedCount`

---

## Verificación

Al finalizar el lab, el estudiante debe poder verificar:

- [ ] **Trail creado**: En CloudTrail, confirmar que existe `security-audit-trail` con estado **Logging**

- [ ] **Bucket de logs**: En S3, confirmar que existe el bucket `cloudtrail-logs-*` con prefijos de logs

- [ ] **Log group existe**: En CloudWatch Logs, confirmar `/aws/cloudtrail/security-audit`

- [ ] **Log streams activos**: Ver eventos en los log streams del grupo

- [ ] **Metric filter creado**: En CloudWatch, confirmar filtro `ConsoleLoginFilter` en namespace `CloudTrailMetrics`

- [ ] **Alarma creada**: En CloudWatch Alarms, confirmar alarma con estado **OK** o **Insufficient data**

- [ ] **Eventos aparecen**: Después de generar actividad, verificar eventos en Event history

---

## Errores Comunes y Soluciones

| Error | Causa | Solución |
|-------|-------|----------|
| Trail no graba eventos | Permisos IAM insuficientes | Verificar que el rol del trail tiene permisos para escribir en S3 y CloudWatch Logs |
| Email de alarma no llega | Suscripción SNS no confirmada | Revisar bandeja de entrada y spam, hacer clic en confirmar suscripción |
| No hay datos en metric filter | Events aún no procesados | Esperar 5-10 minutos; CloudTrail procesa logs de forma asíncrona |
| Log group no aparece | Creación fallida en background | Verificar que el rol tiene permisos `logs:CreateLogGroup` |
| Alarm en estado Insufficient data | Metric filter no creó datos | Verificar filter pattern, ejecutar eventos de ConsoleLogin |

---

## Limpieza (Opcional)

Para evitar costos:

1. **Eliminar trail**:
   - CloudTrail > Trails > Seleccionar trail > Delete

2. **Eliminar log group**:
   - CloudWatch > Logs > Select group > Delete log group

3. **Eliminar alarma**:
   - CloudWatch > Alarms > Select alarm > Delete

4. **Eliminar bucket S3** (si no se necesita):
   - S3 > Select bucket > Empty > Delete bucket

---

## Referencias

- [CloudTrail User Guide](https://docs.aws.amazon.com/awscloudtrail/latest/userguide/)
- [CloudWatch Logs Integration](https://docs.aws.amazon.com/awscloudtrail/latest/userguide/cloudwatch-logs.html)
- [CloudWatch Metrics and Dimensions](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/EC2Metrics.html)
- [Metric Filter and Alarm Examples](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/MonitorWebsiteMetrics.html)
