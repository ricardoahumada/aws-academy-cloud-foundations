# Lab 5.1: Estimación, Control y Optimización de Costes

## Objetivo

Planificar presupuestos, configurar alertas, analizar costos con Cost Explorer y aplicar estrategias de tagging para control financiero en AWS.

Al finalizar este lab, el estudiante será capaz de:
- Navegar el Billing Dashboard de AWS
- Crear AWS Budgets con alertas configuradas
- Utilizar Cost Explorer para generar reportes de costos
- Implementar una estrategia de tagging para atribución de costos
- Analizar rightsizing recommendations
- Estimar costos de arquitecturas usando AWS Pricing Calculator

## Duración estimada

90 minutos

## Prerrequisitos

- Cuenta AWS con acceso a Billing Console
- Permisos IAM para: Budgets, Cost Explorer, CloudWatch
- Acceso al email configurado para recibir alertas
- Navegador web actualizado

---

## Pasos

### Paso 1: Explorar el Billing Dashboard

1.1. Iniciar sesión en la AWS Console en https://console.aws.amazon.com

1.2. En la barra de búsqueda superior, escribir `Billing` y seleccionar **Billing Dashboard**

1.3. En la sección **Current Month Spend**, observar:
   - Gasto total del mes actual
   - Pronóstico (Forecast) de gasto
   - Servicios con mayor costo (Top services by cost)

1.4. Hacer clic en cada uno de los siguientes enlaces del menú lateral izquierdo y familiarizarse con su contenido:
   - **Cost Explorer**
   - **Budgets**
   - **Bills**
   - **Cost Categories**

1.5. Tomar un screenshot del overview del Billing Dashboard para referencia futura

---

### Paso 2: Crear un Budget Mensual

2.1. En el menú lateral izquierdo, hacer clic en **Budgets**

2.2. Hacer clic en **Create budget**

2.3. En la página de configuración del budget, seleccionar **Cost budget** y hacer clic en **Next**

2.4. En la sección **Budget setup**:
   - **Name**: `lab-budget-<tu-nombre>` (ejemplo: `lab-budget-juan`)
   - **Period**: Monthly
   - **Budgeted amount**: $50.00 USD

2.5. En la sección **Budget scope**, dejar los filtros vacíos para aplicar a toda la cuenta

2.6. En la sección **Configure alert thresholds**:
   - **Alert threshold 1**: 80% ($40.00 USD)
   - **Alert threshold 2**: 100% ($50.00 USD)
   - Para cada threshold, ingresar un email válido en **Email recipients**

2.7. (Opcional) En la sección **Actions**, configurar:
   - **Action type**: SNS notification
   - **ARN**: Crear un SNS topic nuevo o usar uno existente

2.8. Hacer clic en **Create budget**

2.9. Verificar que el budget aparece en la lista con estado **Active**

---

### Paso 3: Configurar y Usar Cost Explorer

3.1. En el menú lateral izquierdo, hacer clic en **Cost Explorer**

3.2. Si Cost Explorer no está habilitado, hacer clic en **Enable Cost Explorer** y esperar hasta 24 horas (nota: para este lab, continuar con los datos históricos disponibles)

3.3. Una vez en Cost Explorer, hacer clic en **Create report**

3.4. Configurar el reporte con los siguientes parámetros:
   - **Filter**: Service equals Amazon EC2
   - **Group by**: Region
   - **Time period**: Last 6 months
   - **Granularity**: Monthly

3.5. En la esquina superior derecha, hacer clic en **Save report**

3.6. Ingresar `EC2-costs-by-region` como nombre del reporte y hacer clic en **Save**

3.7. Tomar un screenshot del reporte generado

3.8. Modificar el reporte para ver costos por **Service** (remover el Group by anterior y agrupar por Service)

3.9. Guardar este segundo reporte como `costs-by-service`

---

### Paso 4: Implementar Estrategia de Tagging

4.1. En la barra de búsqueda superior, escribir `Resource Groups` y seleccionar **Resource Groups**

4.2. Hacer clic en **Tag Editor** en el submenú

4.3. En Tag Editor, configurar los siguientes filtros:
   - **Region**:us-east-1
   - **Resource types**: Amazon EC2 Instance, Amazon RDS DB Instance, Amazon S3 Bucket

4.4. Hacer clic en **Search resources**

4.5. Para cada recurso encontrado, agregar los siguientes tags (si no existen):
   - **Environment**: `development`, `production`, o `testing`
   - **Department**: `engineering`, `marketing`, o `finance`
   - **Project**: `analytics`, `website`, o `api`
   - **Owner**: `<tu-nombre-o-email>`

4.6. Hacer clic en **Apply changes** para guardar los tags

4.7. Ir a **Resource Groups** > **Create resource group**

4.8. Configurar el resource group:
   - **Name**: `production-resources`
   - **Group type**: Tag based
   - **Tag key**: Environment
   - **Tag value**: production

4.9. Hacer clic en **Create group**

4.10. Verificar que los recursos de producción aparecen en el grupo

---

### Paso 5: Crear Report de Costos con Tags

5.1. Regresar a **Cost Explorer**

5.2. Hacer clic en **Create report**

5.3. Configurar el reporte:
   - **Filter**: tag:environment equals production
   - **Group by**: Service
   - **Time period**: Last 3 months

5.4. Guardar el reporte como `production-costs`

5.5. Crear otro reporte:
   - **Filter**: tag:department equals engineering
   - **Group by**: Linked Account (si aplica) o Region

5.6. Guardar como `engineering-costs`

---

### Paso 6: Revisar Rightsizing Recommendations

6.1. En Cost Explorer, hacer clic en **Rightsizing Recommendations** en el menú izquierdo

6.2. Revisar las recomendaciones presentadas para instancias EC2

6.3. Aplicar filtros:
   - **Potential monthly savings**: Greater than $5
   - **Instance family**: Contains t3

6.4. Seleccionar 2-3 recomendaciones para analizar en detalle

6.5. Para cada recomendación, documentar:
   - Nombre de la instancia actual
   - Tipo de instancia actual
   - Instancia recomendada
   - Ahorro mensual proyectado
   - Porcentaje de ahorro

6.6. Hacer clic en una recomendación específica y seleccionar **View resource details**

6.7. Documentar los detalles de utilization (CPU, Network) que sustenta la recomendación

---

### Paso 7: Configurar CloudWatch Billing Alert (Alternativa)

7.1. En la barra de búsqueda, escribir `CloudWatch` y seleccionar **CloudWatch**

7.2. En el menú izquierdo, hacer clic en **Alarms** > **All alarms**

7.3. Hacer clic en **Create alarm**

7.4. Hacer clic en **Select metric** y luego en **Billing** > **Estimated Charges**

7.5. Seleccionar la métrica **EstimatedCharges** para tu cuenta

7.6. En la configuración del alarm:
   - **Threshold**: $10.00 USD
   - **Condition**: Greater than
   - **Period**: 6 hours
   - **Statistic**: Maximum

7.7. En **Notification**:
   - **Alarm state trigger**: In alarm
   - **Send notification to**: Create new SNS topic
   - **Email endpoint**: Tu email válido

7.8. Hacer clic en **Create topic**, ingresar un nombre y tu email, luego hacer clic en **Create topic**

7.9. Hacer clic en **Next** y luego en **Create alarm**

7.10. Verificar que el alarm aparece en la lista con estado **OK**

---

### Paso 8: Estimar Costo de Arquitectura con AWS Pricing Calculator

8.1. Abrir un nueva pestaña del navegador e ir a https://calculator.aws/

8.2. Hacer clic en **Create estimate**

8.3. En **Add service**, buscar y agregar **Amazon EC2**

8.4. Configurar la instancia EC2:
   - **Region**: US East (N. Virginia)
   - **Operating System**: Linux
   - **Instance type**: t3.micro
   - **Instance usage**: 750 hours/month (Always Free)
   - **Load model**: On-demand
   - **Number of instances**: 2

8.5. Hacer clic en **Add Row** y agregar **Amazon RDS**:
   - **Region**: US East (N. Virginia)
   - **DB engine**: MySQL
   - **DB instance class**: db.t3.micro
   - **Deployment option**: Multi-AZ
   - **Storage**: 20 GB
   - **Instance usage**: 750 hours/month

8.6. Hacer clic en **Add Row** y agregar **Amazon S3**:
   - **Region**: US East (N. Virginia)
   - **Storage class**: S3 Standard
   - **Storage**: 10 GB/month
   - **GET requests**: 10,000/month
   - **PUT requests**: 1,000/month

8.7. Hacer clic en **Add Row** y agregar **Data Transfer**:
   - **Region**: US East (N. Virginia)
   - **Outbound data transfer**: 100 GB/month

8.8. Revisar el **Monthly estimate** y **Year 1 estimate** presentados

8.9. Hacer clic en **Save estimate** y nombrar `basic-web-architecture-lab`

8.10. Documentar el costo mensual y anual estimado

---

## Verificación

Al finalizar este lab, el estudiante debe poder demostrar:

- [ ] Navega el Billing Dashboard e identifica las secciones principales
- [ ] Crea un AWS Budget mensual con alertas configuradas al 80% y 100%
- [ ] Utiliza Cost Explorer para crear un reporte filtrado por servicio y agrupado por región
- [ ] Implementa tags en recursos (Environment, Department, Project, Owner)
- [ ] Crea un resource group basado en tags
- [ ] Genera un reporte de costos filtrado por tag
- [ ] Analiza rightsizing recommendations y documenta ahorros potenciales
- [ ] Configura una CloudWatch billing alarm
- [ ] Estima costos de arquitectura usando AWS Pricing Calculator

---

## Errores Comunes y Soluciones

| Error | Causa | Solución |
|-------|-------|----------|
| No puedo acceder a Billing | Usuario sin permisos de billing | Verificar que la cuenta tiene permisos de billing o usar cuenta root |
| Budget no se crea | Filtros muy restrictivos | Simplificar el scope del budget |
| Cost Explorer sin datos | Explorer recién habilitado | Esperar 24 horas o usar datos de meses anteriores |
| Tags no aparecen en Cost Explorer | Tags no propagados | Esperar hasta 24 horas para que tags aparezcan en costos |
| Alarm no envía notificaciones | Email no verificado en SNS | Verificar el email y confirmar suscripción |

---

## Recursos Adicionales

- [AWS Billing Documentation](https://docs.aws.amazon.com/awsaccountbilling/latest/aboutv2/billing-what-is.html)
- [AWS Cost Explorer User Guide](https://docs.aws.amazon.com/cost-management/latest/userguide/ce-what-is.html)
- [AWS Budgets Documentation](https://docs.aws.amazon.com/cost-management/latest/userguide/budgets-managing-cost.html)
- [Tagging Best Practices](https://docs.aws.amazon.com/general/latest/gr/aws_tagging.html)
- [AWS Pricing Calculator](https://docs.aws.amazon.com/pricing-calculator/latest/userguide/what-is.html)

---

## Limpieza de Recursos

Al finalizar el lab, es importante eliminar o deshabilitar los recursos creados para evitar costos innecesarios:

**Desde la consola AWS:**

1. **Eliminar el Budget creado:**
   - Ir a **Billing Dashboard** > **Budgets**
   - Seleccionar el budget `lab-budget-<tu-nombre>`
   - Hacer clic en **Actions** > **Delete**
   - Confirmar la eliminación

2. **Eliminar la CloudWatch Alarm:**
   - Ir a **CloudWatch** > **Alarms** > **All alarms**
   - Seleccionar la alarma creada (ej: `billing-alert`)
   - Hacer clic en **Actions** > **Delete**
   - Confirmar la eliminación

3. **Eliminar el SNS Topic (si se creó):**
   - Ir a **SNS** > **Topics**
   - Seleccionar el topic creado
   - Hacer clic en **Delete**
   - Ingresar el nombre del topic para confirmar

4. **Eliminar el Resource Group (opcional):**
   - Ir a **Resource Groups** > **Saved Resource Groups**
   - Seleccionar el grupo `production-resources`
   - Hacer clic en **Delete resource group**
   - Confirmar la eliminación

**Desde AWS CLI:**

```bash
# Eliminar CloudWatch alarm
aws cloudwatch delete-alarms --alarm-names billing-alert

# Eliminar SNS topic
aws sns delete-topic --topic-arn "arn:aws:sns:us-east-1:123456789012:billing-alert-topic"

# Eliminar budgets
aws budgets delete-budget --account-id 123456789012 --budget-name "lab-budget-tu-nombre"
```

**Nota:** Los recursos de tagging no requieren eliminación ya que son solo metadatos. El AWS Pricing Calculator no genera costos ya que es solo una herramienta de estimación.
