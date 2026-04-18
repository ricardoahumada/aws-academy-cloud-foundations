# Lab 5.2: Análisis de Savings Plans vs Reserved Instances

## Objetivo

Comparar diferentes escenarios de compromiso de compute y calcular ahorros potenciales para tomar decisiones informadas sobre la compra deReserved Instances y Savings Plans en AWS.

Al finalizar este lab, el estudiante será capaz de:
- Analizar el uso actual de EC2 mediante Cost Explorer
- Calcular costos baseline con precios On-Demand
- Comparar precios entre Reserved Instances y Savings Plans
- Crear una matriz de comparación de costos
- Determinar la estrategia de compromiso óptima según el workload

## Duración estimada

30 minutos

## Prerrequisitos

- Cuenta AWS con acceso a Cost Explorer
- Acceso a AWS Pricing Calculator: https://calculator.aws/
- Datos históricos de uso de EC2 de al menos 7 días

---

## Pasos

### Paso 1: Analizar el Uso Actual de EC2

1.1. Iniciar sesión en la AWS Console en https://console.aws.amazon.com

1.2. Ir a **Billing Dashboard** > **Cost Explorer**

1.3. Hacer clic en **Create report**

1.4. Configurar el reporte inicial:
   - **Filter**: Service equals Amazon EC2
   - **Group by**: None
   - **Time period**: Last 30 days
   - **Granularity**: Daily

1.5. Hacer clic en **Apply**

1.6. Revisar los datos mostrados y observar:
   - Variación diaria de uso
   - Patrones de uso (días de mayor/menor consumo)

1.7. En la esquina superior derecha, hacer clic en **Download CSV** o **Export**

1.8. Guardar el archivo exportado para análisis posterior

1.9. Calcular manualmente:
   - Promedio de horas de uso diario de EC2
   - Uso máximo y mínimo observado
   - Identificar si hay un "baseload" (uso mínimo constante)

---

### Paso 2: Escenario On-Demand (Baseline)

2.1. Abrir una nueva pestaña del navegador e ir a https://calculator.aws/

2.2. Hacer clic en **Create estimate**

2.3. Buscar y seleccionar **Amazon EC2**

2.4. Configurar el escenario baseline:
   - **Region**: US East (N. Virginia)
   - **Operating System**: Linux
   - **Instance type**: t3.micro
   - **Instance details**:
     - **Load model**: On-demand
     - **Number of instances**: 1
     - **Hours per instance per day**: 24
     - **Days per month**: 30

2.5. Verificar que el cálculo muestra el precio On-Demand completo

2.6. Anotar el costo mensual y anual:
   - **Costo Mensual On-Demand**: $ ______

2.7. Hacer clic en **Save estimate** y nombrar `on-demand-baseline`

---

### Paso 3: Escenario Reserved Instance 1-Year No Upfront

3.1. En el mismo estimate, hacer clic en **Add to estimate**

3.2. Agregar otro servicio EC2 con las mismas características base

3.3. Modificar las opciones de compra:
   - **Load model**: Reserved
   - **Term**: 1 year
   - **Offering class**: Standard
   - **Payment option**: No Upfront

3.4. Anotar el costo con este escenario:
   - **Costo Mensual RI 1-Year No Upfront**: $ ______
   - **Ahorro vs On-Demand**: ______ %

3.5. Guardar el estimate como `ri-1year-no-upfront`

---

### Paso 4: Escenario Compute Savings Plan 1-Year

4.1. Crear un nuevo estimate haciendo clic en **Create estimate**

4.2. Agregar **Amazon EC2** con los mismos parámetros base (t3.micro, 24h/day, 30 days/month)

4.3. Agregar también **AWS Lambda** y **Amazon Fargate** al estimate

4.4. Para cada servicio, cambiar el modelo a **Savings Plans**:
   - **Compute Savings Plans**
   - **Term**: 1 year
   - **Payment option**: No Upfront

4.5. Anotar el costo mensual total:
   - **Costo Mensual Compute SP 1-Year**: $ ______
   - **Ahorro vs On-Demand**: ______ %

4.6. Guardar como `compute-sp-1year`

---

### Paso 5: Escenario Reserved Instance 3-Year All Upfront

5.1. Crear un nuevo estimate

5.2. Agregar **Amazon EC2** t3.micro con:
   - **Load model**: Reserved
   - **Term**: 3 years
   - **Offering class**: Standard
   - **Payment option**: All Upfront

5.3. Anotar el costo:
   - **Costo Mensual RI 3-Year All Upfront**: $ ______
   - **Ahorro vs On-Demand**: ______ %

5.4. Comparar con el escenario All Upfront vs No Upfront:
   - **Diferencia por elegir No Upfront**: $ ______ más por mes

5.5. Guardar como `ri-3year-all-upfront`

---

### Paso 6: Crear Matriz de Comparación

6.1. Abrir una hoja de cálculo o crear una tabla manual

6.2. Crear la siguiente matriz con los datos recopilados:

| Opción | Costo Mensual | Costo Anual | Ahorro vs On-Demand | Flexibilidad | Mejor Uso |
|--------|---------------|-------------|---------------------|--------------|-----------|
| On-Demand (Baseline) | $X.XX | $XXX.XX | - | Máxima | Workloads variables, desarrollo |
| RI 1-Year No Upfront | $X.XX | $XXX.XX | XX% | Media | Baseload predecible |
| RI 3-Year All Upfront | $X.XX | $XXX.XX | XX% | Baja | Sistemas críticos de larga duración |
| Compute SP 1-Year | $X.XX | $XXX.XX | XX% | Alta | Mix de compute (EC2, Lambda, Fargate) |

6.3. Llenar los valores con los datos obtenidos de los estimates

6.4. Analizar la relación entre:
   - Mayor compromiso (3 años vs 1 año)
   - Pago anticipado (All Upfront vs No Upfront)
   - Tipo de Savings Plan (Compute SP vs EC2 Instance SP)

---

### Paso 7: Análisis de Cobertura y Recomendaciones

7.1. Regresar a la AWS Console > **Cost Explorer**

7.2. En el menú izquierdo, hacer clic en **RI Coverage**

7.3. Revisar el **Coverage Ratio** actual:
   - ¿Qué porcentaje de instancias están cubiertas por RI?
   - ¿Cuántas horas están "uncovered" (On-Demand)?

7.4. En el menú izquierdo, hacer clic en **Savings Plans Coverage**

7.5. Revisar la cobertura actual de Savings Plans

7.6. Basándose en el análisis, determinar la estrategia recomendada:

**Criterios de decisión:**

| Scenario | Recomendación |
|----------|----------------|
| Uso constante 24/7, sin cambios previstos | RI 3-Year All Upfront |
| Uso variable con spikes impredecibles | Compute Savings Plans |
| Desarrollo/Testing con uso irregular | On-Demand o Spot |
| Baseload estable + spikes ocasionales | RI para baseload + On-Demand para spikes |

7.7. Documentar la recomendación final con justificación basada en los datos analizados

---

## Verificación

Al finalizar este lab, el estudiante debe poder demostrar:

- [ ] Extrae y analiza datos de uso de EC2 desde Cost Explorer
- [ ] Calcula el costo On-Demand baseline usando AWS Pricing Calculator
- [ ] Compara precios entre On-Demand, RI y Savings Plans
- [ ] Llena la matriz de comparación con datos reales
- [ ] Interpreta RI Coverage y Savings Plans Coverage
- [ ] Proporciona una recomendación de compromiso basada en el workload

---

## Escenario de Reflexión

Dado el siguiente perfil de workload, determinar la estrategia óptima:

**Workload Profile:**
- Baseload: 2 instancias t3.micro ejecutándose 24/7
- Spikes: 0-3 instancias adicionales durante business hours (8am-6pm, L-V)
- Duración estimada: 18 meses

**Preguntas a resolver:**
1. ¿Cuántas horas al mes son "baseload" vs "variable"?
2. ¿Qué porcentaje debería tener RI vs On-Demand?
3. ¿RI 1-year o 3-year? ¿Por qué?
4. ¿Compute SP o EC2 Instance SP?
5. ¿All Upfront o Partial Upfront?

---

## Errores Comunes y Soluciones

| Error | Causa | Solución |
|-------|-------|----------|
| Precios diferentes a los esperados | Región incorrecta seleccionada | Verificar que la región sea US East (N. Virginia) para precios base |
| Savings Plans no aparece como opción | Tipo de servicio incorrecto | Compute SP aplica a EC2, Lambda y Fargate juntos |
| No hay datos de cobertura | Cost Explorer no habilitado | Habilitar Cost Explorer (toma hasta 24h) |
| Savings calculados parecen incorrectos | Mezclar instance types diferentes | Usar el mismo instance type para comparación limpia |

---

## Recursos Adicionales

- [Reserved Instances Documentation](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-reserved-instances.html)
- [Savings Plans Documentation](https://docs.aws.amazon.com/savingsplans/latest/userguide/what-is-savings-plans.html)
- [AWS Cost Explorer RI Coverage](https://docs.aws.amazon.com/cost-management/latest/userguide/ri-coverage.html)
- [AWS Pricing Calculator](https://docs.aws.amazon.com/pricing-calculator/latest/userguide/getting-started.html)
- [RI vs SP Decision Guide](https://docs.aws.amazon.com/savingsplans/latest/userguide/sp-applying.html)

---

## Limpieza de Recursos

Este lab utiliza AWS Pricing Calculator, que es una herramienta de estimación y **no genera costos**. Sin embargo, es buena práctica limpiar los estimates guardados:

**Desde AWS Pricing Calculator:**

1. Abrir [AWS Pricing Calculator](https://calculator.aws/)
2. Iniciar sesión con tu cuenta AWS
3. Ir a **My estimate** > **Saved estimates**
4. Eliminar los estimates creados:
   - `on-demand-baseline`
   - `ri-1year-no-upfront`
   - `compute-sp-1year`
   - `ri-3year-all-upfront`
5. Hacer clic en **Delete** para cada estimate

**Desde AWS Console (Cost Explorer):**

Si creaste reportes guardados en Cost Explorer:
1. Ir a **Billing Dashboard** > **Cost Explorer**
2. Ir a **Saved reports**
3. Eliminar los reportes guardados:
   - `EC2-costs-by-region`
   - `costs-by-service`
   - `production-costs`
   - `engineering-costs`

**Nota:** No se requieren pasos de cleanup en la consola AWS ya que este lab solo utiliza herramientas de análisis (Cost Explorer, Pricing Calculator) que no crean recursos facturables.
