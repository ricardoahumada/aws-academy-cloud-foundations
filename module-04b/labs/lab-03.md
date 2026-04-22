# Lab 4b.3: Monitoreo Automatizado con CloudWatch Application Insights

**Duración:** 30 minutos  
**Nivel:** Intermedio  
**Servicios:** CloudWatch Application Insights, CloudWatch, Resource Groups, EC2, Lambda, ALB

---

## Objetivo del Lab

Configurar CloudWatch Application Insights para una aplicación de producción que incluya instancias EC2 (backend), funciones Lambda (procesamiento asíncrono) y Application Load Balancer. Al finalizar, el monitoreo automatizado detectará problemas sin necesidad de configuración manual de umbrales.

---

## Escenario

El equipo de operaciones ha desplegado una aplicación web en producción que necesita monitoreo automatizado. La aplicación consiste en:

- Instancias EC2 ejecutando el servicio backend
- Funciones Lambda para procesamiento asíncrono de pedidos
- Application Load Balancer para distribución de tráfico

El equipo necesita detectar problemas automáticamente utilizando machine learning, sin tener que configurar umbrales manuales para cada métrica.

---

## Prerrequisitos

- Acceso a la consola de AWS con permisos para CloudWatch Application Insights y Resource Groups
- Un Resource Group creado conteniendo los recursos de la aplicación (EC2, Lambda, ALB)
- Logs de aplicación configurados en CloudWatch Logs
- Permisos IAM: `applicationinsights:*`, `cloudwatch:*`, `resource-groups:*`

---

## Recursos Necesarios

| Recurso | Descripción |
|---------|-------------|
| 1 Resource Group | `ProductionApp-RG` conteniendo EC2, Lambda, ALB |
| 1-2 Instancias EC2 | Backend de la aplicación con CloudWatch Agent |
| 2-3 Funciones Lambda | Procesamiento asíncrono |
| 1 Application Load Balancer | Punto de entrada de la aplicación |
| 1 CloudWatch Log Group | Logs de aplicación (`/aws/lambda/*`) |

---

## Arquitectura de Referencia

```
┌─────────────────────────────────────────────────────────────┐
│              Application Insights Monitoring                │
├─────────────────────────────────────────────────────────────┤
│  Resource Group: ProductionApp-RG                           │
│                                                             │
│  ┌─────────────┐   ┌─────────────┐   ┌─────────────┐        │
│  │    EC2      │   │   Lambda    │   │     ALB     │        │
│  │  (Backend)  │   │ (Async Proc)│   │   (Web)     │        │
│  └─────────────┘   └─────────────┘   └─────────────┘        │
│         │                │                  │               │
│         └────────────────┼──────────────────┘               │
│                          ▼                                  │
│              ┌──────────────────────────┐                   │
│              │  Auto-detected Problems  │                   │
│              │  (ML-powered Detection)  │                   │
│              └──────────────────────────┘                   │
└─────────────────────────────────────────────────────────────┘
```

---

## Paso a Paso

### Parte 1: Crear Application Insight

1. Iniciar sesión en la consola de AWS
2. Navegar a **CloudWatch** > **Application Insights**
3. Hacer clic en **Create application**
4. En la sección **Resource group**:
   - Seleccionar el Resource Group: `ProductionApp-RG`
   - Verificar que los recursos son detectados automáticamente
5. Hacer clic en **Create**
6. Esperar a que Application Insights termine de configurar el monitoreo (2-3 minutos)

### Parte 2: Verificar Componentes Detectados

7. Una vez creado, navegar a la pestaña **Components**
8. Verificar que los siguientes componentes aparecen listados:
   - Instancias EC2 (backend)
   - Funciones Lambda (async-processor, notification)
   - Application Load Balancer
9. Si algún componente no aparece, hacer clic en **Add component** y seleccionarlo manualmente

### Parte 3: Configurar Patrones de Logs

10. Navegar a la pestaña **Log patterns**
11. Hacer clic en **Add pattern set**
12. Configurar el conjunto de patrones:
    - **Pattern set name**: `ErrorPatterns`
    - **Description**: Patrones de errores para aplicación de producción
13. Agregar los siguientes patrones:

| Pattern Name | Pattern | Priority |
|--------------|---------|----------|
| ErrorPattern | `error|exception|fail|timeout` | 1 |
| WarningPattern | `warn|deprecated|retry` | 2 |
| LatencyPattern | `latency|slow|timeout` | 3 |

14. Hacer clic en **Save**

### Parte 4: Configurar Monitoreo de Métricas

15. Navegar a la pestaña **Metrics and Logs**
16. Verificar que las siguientes métricas están habilitadas para monitoreo:

| Componente | Métricas Habilitadas |
|------------|----------------------|
| EC2 | CPUUtilization, NetworkIn, NetworkOut, DiskReadBytes |
| Lambda | Invocations, Errors, Duration, Throttles |
| ALB | RequestCount, TargetResponseTime, HealthyHostCount, UnHealthyHostCount |

17. Si alguna métrica no está habilitada, marcarla para monitoreo
18. Hacer clic en **Save**

### Parte 5: Verificar Detección Automática

19. Navegar a la pestaña **Problems**
20. Esperar 5-10 minutos para que el sistema realice la primera correlación de datos
21. Si no hay problemas recientes, el dashboard mostrará "No problems detected"
22. Para generar datos de prueba, ejecutar carga en la aplicación o provocar errores intencionales

### Parte 6: Crear Alarma desde Problema Detectado

23. Cuando aparezca un problema detectado, hacer clic en él para ver los detalles
24. En la sección **Actions**, hacer clic en **Create alarm**
25. Configurar la alarma:
    - **Alarm name**: `ApplicationInsights-{ResourceGroup}-ProblemAlert`
    - **Severity**: High
    - **SNS Topic**: Seleccionar o crear un SNS topic para notificaciones
26. Hacer clic en **Create alarm**

---

## Verificación del Lab

| # | Verificación | Criterio de Éxito |
|---|--------------|-------------------|
| 1 | Application Insight creado | Aparece en CloudWatch > Application Insights con estado "Monitoring" |
| 2 | Componentes detectados | EC2, Lambda y ALB visibles en la pestaña Components |
| 3 | Patrones de logs configurados | Los 3 patrones (Error, Warning, Latency) aparecen en Log patterns |
| 4 | Métricas habilitadas | Al menos 3 métricas por componente están habilitadas |
| 5 | Dashboard de problemas | La pestaña Problems muestra el estado del aplicativo |

---

## Comandos AWS CLI

```bash
# Crear Application Insight
aws applicationinsights create-application \
    --resource-group-name "ProductionApp-RG" \
    --ops-center-enabled \
    --auto-config-enabled

# Listar Application Insights
aws applicationinsights list-applications

# Listar componentes de un Application Insight
aws applicationinsights list-components \
    --resource-group-name "ProductionApp-RG"

# Listar problemas detectados
aws applicationinsights list-problems \
    --resource-group-name "ProductionApp-RG" \
    --max-results 10

# Describir detalle de un problema
aws applicationinsights describe-problem \
    --problem-id "p-xxxxxxxxx"

# Crear patrón de log
aws applicationinsights create-log-pattern \
    --resource-group-name "ProductionApp-RG" \
    --pattern-set-name "ErrorPatterns" \
    --pattern-name "ErrorPattern" \
    --pattern "error|exception|fail|timeout" \
    --rank 1

# Listar patrones de log
aws applicationinsights list-log-patterns \
    --resource-group-name "ProductionApp-RG"

# Eliminar Application Insight (limpieza)
aws applicationinsights delete-application \
    --resource-group-name "ProductionApp-RG"
```

---

## Errores Comunes y Soluciones

| Error | Causa | Solución |
|-------|-------|----------|
| "No components found" | Componentes no están en el Resource Group | Verificar que los recursos están en el mismo Resource Group |
| Problemas no se detectan | Falta de datos de métricas/logs | Esperar 15-30 minutos para que se acumulen datos |
| Sin datos de métricas EC2 | CloudWatch Agent no instalado | Instalar y configurar CloudWatch Agent en EC2 |
| Patrones no reconocen logs | Formato de log incorrecto | Verificar que los logs coinciden con el patrón definido |
| Error en create-application | Permisos insuficientes | Verificar que el rol IAM tiene permisos `applicationinsights:*` |

---

## Notas sobre Cambios Recientes (Abr 2026)

- **Application Insights ahora detecta automáticamente** más tipos de recursos incluyendo containers ECS y microservicios EKS
- **Interfaz mejorada** para la configuración de patrones de log con preview en tiempo real
- **Integración con DevOps Guru** disponible para correlación automática de problemas

---

## Recursos Adicionales

- [Documentación oficial CloudWatch Application Insights](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/appinsights-what-is.html)
- [AWS CLI para Application Insights](https://docs.aws.amazon.com/cli/latest/reference/application-insights/)
