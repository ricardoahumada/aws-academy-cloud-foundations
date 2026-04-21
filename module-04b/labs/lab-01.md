# Lab 4b.1: Dashboard Personalizado con Métricas de EC2, ALB y CloudWatch Logs

**Duración:** 30 minutos  
**Nivel:** Intermedio  
**Servicios:** CloudWatch, EC2, Application Load Balancer, CloudWatch Logs

---

## Objetivo del Lab

Crear un dashboard personalizado en CloudWatch que permita monitorear en tiempo real una aplicación web. El dashboard integrará métricas de CPU de EC2, latencia del Application Load Balancer, errores en tiempo real de CloudWatch Logs y estado de alarmas configuradas.

---

## Prerrequisitos

- Acceso a la consola de AWS con permisos para crear dashboards y visualizar métricas
- Al menos una instancia EC2 con el agente CloudWatch instalado y ejecutándose
- Un Application Load Balancer configurado con métricas habilitadas
- Un grupo de logs en CloudWatch Logs con logs de aplicación (formato ACCESS_LOG)

---

## Recursos Necesarios

| Recurso | Descripción |
|---------|-------------|
| 1 Instancia EC2 | Con CloudWatch Agent instalado y métricas de CPU habilitadas |
| 1 Application Load Balancer | Con métricas TargetResponseTime y RequestCount |
| 1 CloudWatch Log Group | Recibe logs de la aplicación en formato ACCESS_LOG |
| 1 CloudWatch Alarm | Previamente configurada para CPU > 80% |

---

## Arquitectura de Referencia

```
┌─────────────────────────────────────────────────────────────┐
│                    CloudWatch Dashboard                     │
├───────────────────────┬─────────────────────────────────────┤
│  Métricas EC2         │    Métricas ALB                     │
│  - CPUUtilization     │    - TargetResponseTime             │
│  - NetworkIn          │    - RequestCount                   │
├───────────────────────┼─────────────────────────────────────┤
│  Logs Insights        │    Alarmas Activas                  │
│  Errores detectados   │    - CPU-High-Alarm                 │
└───────────────────────┴─────────────────────────────────────┘
```

---

## Paso a Paso

### Parte 1: Acceso a la Consola de CloudWatch

1. Iniciar sesión en la consola de AWS
2. Navegar a **CloudWatch** > **Dashboards**
3. Hacer clic en **Create dashboard**
4. Ingresar el nombre: `ProductionWebApp-Dashboard`
5. Seleccionar **Add widget** para comenzar a agregar widgets

### Parte 2: Agregar Widget de Métricas EC2

6. Hacer clic en **Add widget** y seleccionar **Line** (gráfico de líneas)
7. En la sección de métricas:
   - Buscar y seleccionar **AWS/EC2**
   - Seleccionar la métrica **CPUUtilization**
   - En **Dimensions**, elegir **InstanceId** y seleccionar la instancia `i-xxxxxxxx`
   - Configurar **Period**: 5 minutes (300 segundos)
   - Configurar **Stat**: Average
8. Hacer clic en **Apply** para agregar el widget
9. Editar el título del widget a: `CPU EC2 - Producción`

### Parte 3: Agregar Widget de Métricas ALB

10. Hacer clic en **Add widget** nuevamente
11. Seleccionar **Line** como tipo de widget
12. En la configuración de métricas:
    - Buscar y seleccionar **AWS/ApplicationELB**
    - Seleccionar la métrica **TargetResponseTime**
    - En **Dimensions**, elegir **LoadBalancer** y seleccionar el ALB `app/mi-alb/xxxxx`
    - Configurar **Period**: 5 minutes (300 segundos)
    - Configurar **Stat**: p95 (percentil 95)
13. Hacer clic en **Apply**
14. Editar el título a: `Latencia ALB - p95`

### Parte 4: Agregar Widget de Logs Insights para Errores

15. Hacer clic en **Add widget**
16. Seleccionar **Logs Insights** como tipo de widget
17. Seleccionar el grupo de logs: `/aws/lambda/mi-funcion` (o el grupo correspondiente)
18. Ingresar la siguiente query:

```sql
fields @timestamp, @message
| filter @message like /(?i)error/
| sort @timestamp desc
| limit 20
```

19. Configurar **Time range**: Last 15 minutes
20. Hacer clic en **Apply**
21. Editar el título a: `Errores en Tiempo Real`

### Parte 5: Agregar Widget de Alarma

22. Hacer clic en **Add widget**
23. Seleccionar **Alarm** como tipo de widget
24. Buscar y seleccionar la alarma **CPU-High-Alarm** (o la alarma configurada previamente)
25. Hacer clic en **Apply**
26. Editar el título a: `Alarma CPU Alta`

### Parte 6: Organizar y Guardar el Dashboard

27. Arrastrar y redimensionar los widgets para optimizar el espacio:
    - Widgets de métricas (EC2 y ALB) en la fila superior
    - Widgets de logs y alarmas en la fila inferior
28. Hacer clic en **Save dashboard**
29. Verificar que el dashboard se guarda correctamente

### Parte 7: Verificación Automática (Opcional via AWS CLI)

30. Para verificar el dashboard creado mediante CLI:

```bash
# Listar dashboards existentes
aws cloudwatch list-dashboards

# Obtener detalle del dashboard
aws cloudwatch get-dashboard --dashboard-name "ProductionWebApp-Dashboard"
```

---

## Verificación del Lab

Realice las siguientes verificaciones para confirmar que el lab se completó exitosamente:

| # | Verificación | Criterio de Éxito |
|---|--------------|-------------------|
| 1 | Dashboard creado | El dashboard aparece en CloudWatch > Dashboards |
| 2 | Widget EC2 visible | El gráfico muestra datos de CPUUtilization |
| 3 | Widget ALB visible | El gráfico muestra TargetResponseTime con p95 |
| 4 | Widget Logs muestra errores | La query retorna errores de los últimos 15 min |
| 5 | Widget de alarma visible | Muestra el estado actual de la alarma CPU |
| 6 | Datos actualizan automáticamente | Las métricas se refrescan cada 5 minutos |

---

## Errores Comunes y Soluciones

| Error | Causa Probable | Solución |
|-------|----------------|----------|
| Widget EC2 sin datos | InstanceId incorrecto o agente no instalado | Verificar que el InstanceId corresponde a una instancia con CloudWatch Agent activo |
| Query de logs no retorna resultados | El grupo de logs no tiene datos o está en otra región | Confirmar que el log group es el correcto y está en la misma región |
| Métrica ALB no aparece | Namespace incorrecto o ALB sin métricas | Verificar que el ALB tiene métricas habilitadas en CloudWatch |
| Widget de alarma vacío | La alarma no existe o está en otro account | Verificar que la alarma existe en la misma región y account |
| Dashboard no guarda cambios | Permisos insuficientes | Confirmar que el usuario tiene permisos `cloudwatch:PutDashboard` |

---

## Comandos AWS CLI de Referencia

```bash
# Crear dashboard mediante CLI
aws cloudwatch put-dashboard \
    --dashboard-name "ProductionWebApp-Dashboard" \
    --dashboard-body '{
        "widgets": [
            {
                "type": "metric",
                "properties": {
                    "metrics": [["AWS/EC2", "CPUUtilization", "InstanceId", "i-1234567890abcdef0"]],
                    "period": 300,
                    "stat": "Average",
                    "region": "us-east-1",
                    "title": "CPU EC2"
                }
            }
        ]
    }'

# Listar todos los dashboards
aws cloudwatch list-dashboards

# Eliminar un dashboard
aws cloudwatch delete-dashboards --dashboard-names "ProductionWebApp-Dashboard"
```

---

## Limpieza (Opcional)

Si desea eliminar el dashboard creado:

```bash
aws cloudwatch delete-dashboards --dashboard-names "ProductionWebApp-Dashboard"
```

---

## Conclusión

En este lab ha aprendido a crear un CloudWatch Dashboard personalizado que integra múltiples fuentes de datos:

- **Métricas de EC2** para monitoreo de compute
- **Métricas de ALB** para monitoreo de latencia de aplicación
- **Logs Insights** para visualización de errores en tiempo real
- **Alarmas** para estado de alertas configuradas

Este dashboard puede servir como base para un monitoreo proactivo de aplicaciones en producción.
