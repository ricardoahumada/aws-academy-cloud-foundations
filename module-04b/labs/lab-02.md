# Lab 4b.2: Análisis de Logs con CloudWatch Logs Insights

**Duración:** 40 minutos  
**Nivel:** Intermedio  
**Servicios:** CloudWatch, CloudWatch Logs, CloudWatch Logs Insights

---

## Objetivo del Lab

Analizar logs de una aplicación web utilizando CloudWatch Logs Insights para identificar patrones de errores, endpoints con bajo rendimiento y crear alertas automatizadas basadas en los queries guardados.

---

## Escenario

Una aplicación web está experimentando tiempos de respuesta lentos y errores intermitentes. El equipo de operaciones necesita:

1. Identificar los endpoints con mayor latencia
2. Determinar la causa raíz de errores frecuentes (códigos 5xx)
3. Crear un dashboard de monitoreo continuo con queries guardadas
4. Configurar una alarma para detectar spikes de errores

---

## Prerrequisitos

- Acceso a la consola de AWS con permisos para CloudWatch Logs Insights
- Un grupo de logs en CloudWatch Logs con logs de aplicación en formato ACCESS_LOG
- Logs deben incluir: timestamp, método HTTP, path, status code y latency

---

## Formato de Logs Esperado

Los logs de aplicación deben seguir el formato ACCESS_LOG (Apache/Nginx style):

```
2026-04-22T10:30:15.123Z - GET /api/users 200 45ms
2026-04-22T10:30:16.234Z - POST /api/login 401 12ms
2026-04-22T10:30:17.345Z - GET /api/products 500 120ms
2026-04-22T10:30:18.456Z - GET /api/health 200 5ms
2026-04-22T10:30:19.567Z - GET /api/users/123 200 89ms
```

**Estructura del log:**
- `@timestamp`: Timestamp ISO 8601
- `method`: Método HTTP (GET, POST, PUT, DELETE)
- `path`: Ruta del endpoint
- `status`: Código de estado HTTP
- `latency`: Latencia en milisegundos

---

## Recursos Necesarios

| Recurso | Descripción |
|---------|-------------|
| 1 CloudWatch Log Group | Grupo de logs con logs de aplicación en formato ACCESS_LOG |
| Permisos CloudWatch Logs | `logs:FilterLogEvents`, `logs:StartQuery`, `logs:GetQueryResults` |

---

## Paso a Paso

### Parte 1: Explorar los Logs Disponibles

1. Iniciar sesión en la consola de AWS
2. Navegar a **CloudWatch** > **Logs** > **Logs Insights**
3. Seleccionar el grupo de logs: `/aws/lambda/mi-funcion` (o el grupo correspondiente)
4. Ejecutar la siguiente query para explorar la estructura de los logs:

```sql
fields @timestamp, @message
| limit 10
```

5. Analizar los resultados y verificar que los logs tienen el formato esperado
6. Hacer clic en **Save as** > **Saved query** y nombrar: `Explore-Logs`

### Parte 2: Identificar Errores 5xx

7. Modificar la query para identificar todos los errores del servidor:

```sql
fields @timestamp, @message
| filter @message like / 5\d\d /
| sort @timestamp desc
| limit 50
```

8. Ejecutar la query y analizar los resultados
9. Identificar:
   - ¿Cuántos errores 5xx occurred?
   - ¿Qué endpoints generan más errores?
   - ¿Existe algún patrón temporal?
10. Guardar la query como: `Errors-5xx-Last-Hour`

### Parte 3: Analizar Latencia por Endpoint

11. Crear una nueva query para parsear los logs y calcular latencia promedio por endpoint:

```sql
fields @message
| parse @message '* - * * * *' as logTimestamp, method, path, status, latency
| filter path like /\/api\//
| stats avg(latency) as avgLatency, count(*) as requests by path
| sort avgLatency desc
```

12. Ejecutar la query
13. Identificar los 5 endpoints más lentos
14. Guardar la query como: `Latency-By-Endpoint`

### Parte 4: Agregar Errores por Período de Tiempo

15. Crear una query para visualizar errores agrupados por intervalos de 15 minutos:

```sql
fields @timestamp, @message
| filter @message like / 5\d\d /
| stats count(*) as errorCount by bin(15m) as timeSlot
| sort timeSlot desc
```

16. Ejecutar la query
17. Guardar la query como: `Errors-By-Time-Slot`

### Parte 5: Identificar Top IPs con Errores

18. Crear una query para encontrar las direcciones IP que generan más errores:

```sql
fields @message
| parse @message '* - * * * *' as logTimestamp, method, path, status, latency
| filter status >= 500
| stats count(*) as errorCount by path
| sort errorCount desc
| limit 10
```

19. Ejecutar la query
20. Guardar la query como: `Top-Error-Paths`

### Parte 6: Crear Widgets en Dashboard

21. Navegar a **CloudWatch** > **Dashboards**
22. Seleccionar o crear el dashboard `ProductionWebApp-Dashboard`
23. Agregar un nuevo widget de tipo **Logs Insights**
24. Seleccionar la query guardada `Errors-5xx-Last-Hour`
25. Configurar **Time range**: Last hour
26. Hacer clic en **Apply** y guardar

27. Agregar otro widget con la query `Latency-By-Endpoint`
28. Organizar los widgets en el dashboard

### Parte 7: Configurar Alarma para Errores

29. Volver a **CloudWatch** > **Logs** > **Logs Insights**
30. Seleccionar la query `Errors-5xx-Last-Hour`
31. Hacer clic en **Create alarm** (icono de campana)
32. Configurar los parámetros de la alarma:
    - **Metric name**: `Errors5xx`
    - **Period**: 5 minutes
    - **Statistic**: Sum
    - **Threshold**: > 10 errors in 5 minutes
33. Hacer clic en **Create alarm**
34. Configurar:
    - **Alarm name**: `High-5xx-Error-Rate`
    - **SNS Topic**: Seleccionar un topic o crear uno nuevo
    - **Actions**: Configurar notificaciones

### Parte 8: Verificación mediante AWS CLI

35. Para ejecutar queries mediante CLI:

```bash
# Obtener el timestamp actual y hace 1 hora (epoch)
START_TIME=$(date -d '1 hour ago' +%s)
END_TIME=$(date +%s)

# Ejecutar query de errores
aws logs start-query \
    --log-group-name "/aws/lambda/mi-funcion" \
    --start-time $START_TIME \
    --end-time $END_TIME \
    --query-string 'fields @timestamp, @message | filter @message like / 5\d\d / | limit 20'

# Nota: Guardar el queryId retornado para obtener resultados
```

36. Obtener los resultados (reemplazar `<query-id>` con el valor obtenido):

```bash
aws logs get-query-results \
    --query-id "<query-id>"
```

---

## Verificación del Lab

| # | Verificación | Criterio de Éxito |
|---|--------------|-------------------|
| 1 | Query de exploración funciona | Los logs se muestran en formato correcto |
| 2 | Errores 5xx identificados | La query retorna errores del servidor |
| 3 | Latencia por endpoint calculada | Se muestra avgLatency para cada path |
| 4 | Errores por time slot | Gráfico de barras con errores por 15 min |
| 5 | Dashboard con widgets | Al menos 2 widgets de Logs Insights |
| 6 | Alarma creada | La alarma aparece en CloudWatch > Alarms |

---

## Queries de Referencia

### Query 1: Errores 5xx

```sql
fields @timestamp, @message
| filter @message like / 5\d\d /
| sort @timestamp desc
| limit 50
```

### Query 2: Latencia Promedio por Endpoint

```sql
fields @message
| parse @message '* - * * * *' as logTimestamp, method, path, status, latency
| filter path like /\/api\//
| stats avg(latency) as avgLatency, count(*) as requests by path
| sort avgLatency desc
```

### Query 3: Errores por Hora

```sql
fields @timestamp, @message
| filter @message like / 5\d\d /
| stats count(*) as errorCount by bin(1h) as hour
| sort hour desc
```

### Query 4: Top 10 Paths con Más Errores

```sql
fields @message
| parse @message '* - * * * *' as logTimestamp, method, path, status, latency
| filter status >= 500
| stats count(*) as errorCount by path
| sort errorCount desc
| limit 10
```

---

## Errores Comunes y Soluciones

| Error | Causa Probable | Solución |
|-------|----------------|----------|
| Query no retorna resultados | El grupo de logs no tiene datos | Verificar que el log group es correcto y tiene eventos recientes |
| Parse no extrae campos | Formato de log diferente al esperado | Revisar el formato real de los logs y ajustar el parse pattern |
| Latency no es numérico | Campo latency contiene caracteres no numéricos | Usar `parse @message /(?<latencyMs>\d+)/` para extraer solo números |
| Alarma no se dispara | Umbral muy alto o muy bajo | Ajustar el threshold basado en el volumen normal de errores |
| Query timeout | Query muy compleja para el período | Reducir el período de tiempo o simplificar la query |

---

## Comandos AWS CLI Adicionales

```bash
# Listar grupos de logs
aws logs describe-log-groups

# Ver eventos recientes de un grupo
aws logs filter-log-events \
    --log-group-name "/aws/lambda/mi-funcion" \
    --start-time 1713600000 \
    --filter-pattern "ERROR"

# Listar queries guardadas
aws logs describe-queries

# Eliminar query guardada (requiere el queryId, obtenerlo con describe-queries)
aws logs delete-query --query-id "<query-id>"
```

---

## Limpieza (Opcional)

Para eliminar los recursos creados en este lab:

```bash
# Eliminar alarma
aws cloudwatch delete-alarms --alarm-names "High-5xx-Error-Rate"

# Eliminar dashboard
aws cloudwatch delete-dashboards --dashboard-names "ProductionWebApp-Dashboard"
```

---

## Conclusión

En este lab ha aprendido a utilizar CloudWatch Logs Insights para:

- **Explorar y entender** la estructura de logs de aplicación
- **Identificar errores** del servidor mediante queries filtradas
- **Analizar rendimiento** calculando latencia promedio por endpoint
- **Visualizar patrones temporales** de errores con agregaciones
- **Crear dashboards** con queries guardadas para monitoreo continuo
- **Configurar alarmas** automatizadas basadas en umbrales de errores

Estas habilidades son fundamentales para el debugging y monitoreo proactivo de aplicaciones en producción.
