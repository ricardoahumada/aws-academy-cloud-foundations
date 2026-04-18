# Lab 2.3: Almacenamiento S3 con Políticas y Lifecycle

## Objetivo

Crear buckets S3, configurar políticas de acceso, implementar lifecycle policies para transiciones automáticas entre clases de almacenamiento, y explorar las diferentes clases de almacenamiento disponibles en Amazon S3.

---

## Duración Estimada

**60 minutos**

---

## Prerrequisitos

- Cuenta AWS activa con acceso a S3
- Permisos IAM para crear buckets, políticas y lifecycle rules
- AWS CLI configurado (opcional pero recomendado para pasos avanzados)
- Navegador web actualizado

---

## Recursos

- S3 Dashboard en AWS Console
- AWS CLI (opcional)
- Buckets S3 (límite soft: 100 por cuenta)

---

## Arquitectura Objetivo

```
┌─────────────────────────────────────────────────────────────┐
│                     Amazon S3                               │
│                                                              │
│  ┌──────────────────────┐    ┌──────────────────────┐     │
│  │   Bucket: app-data    │    │   Bucket: logs-app    │     │
│  │   ─────────────────   │    │   ─────────────────   │     │
│  │   Standard (hot)      │    │   Standard/IA/Glacier │     │
│  │   Datos frecuentes    │    │   Transición automática│     │
│  └──────────────────────┘    └──────────────────────┘     │
│                                                              │
│  Lifecycle Rules:                                           │
│  logs/ → S3 IA (30 días) → Glacier (90 días) → Delete(365)  │
└─────────────────────────────────────────────────────────────┘
```

---

## Pasos

### Paso 1: Crear Bucket S3 Principal

**Tiempo estimado:** 10 minutos

1. Abrir la consola de AWS y navegar a **S3 Dashboard**

2. Hacer clic en **Create bucket**

3. **Configurar propiedades del bucket:**

   #### 3.1 Configuración General
   - **Bucket name:** `lab02-appdata-<nombre>-<fecha>` 
     - Ejemplo: `lab02-appdata-juan-20260331`
     - **Importante:** El nombre debe ser único globalmente (no puede haber dos buckets con el mismo nombre en AWS)
   - **Region:** `US East (N. Virginia)` - us-east-1

   #### 3.2 Configuración de Objects
   - **Object Ownership:** ACLs disabled (recommended)
   - **Block Public Access settings for this bucket:** 
     - ✓ Block all public access (mantener seleccionado para seguridad)
   - **Tags (opcional):**
     - Key: `Environment`, Value: `Lab`
     - Key: `Owner`, Value: `Estudiante`

   #### 3.3 Versioning
   - **Bucket Versioning:** Disable (para este lab básico)

4. Hacer clic en **Create bucket**

**Verificación:** El bucket aparece en la lista con estado `Objects: 0`.

---

### Paso 2: Subir Objetos via Consola

**Tiempo estimado:** 10 minutos

#### 2.1 Crear archivo de prueba

1. Crear archivo localmente con el siguiente contenido:

   **Windows (PowerShell):**
   ```powershell
   "Archivo de prueba para S3 Lab 02 - $(Get-Date)" | Out-File -FilePath .\sample-data.txt
   ```

   **Linux/Mac:**
   ```bash
   echo "Archivo de prueba para S3 Lab 02 - $(date)" > sample-data.txt
   ```

#### 2.2 Subir el archivo

1. En S3 Dashboard, hacer clic en el bucket `lab02-appdata-<nombre>-<fecha>`

2. Hacer clic en **Upload**

3. En la página Upload:
   - Hacer clic en **Add files**
   - Seleccionar el archivo `sample-data.txt` creado

4. Expandir **Additional upload options** (opcional):
   - **Storage class:** Standard
   - **Server-side encryption:** None (para este lab)

5. Hacer clic en **Upload**

6. **Verificación:** El archivo debe aparecer en la lista con:
   - Key: `sample-data.txt`
   - Storage class: `Standard`
   - Size: ~60 bytes

#### 2.3 Subir más objetos de prueba

1. Crear carpeta local llamada `logs`:

   **Windows:**
   ```powershell
   mkdir logs
   "Log entry 1 - $(Get-Date)" | Out-File .\logs\app.log
   "Log entry 2 - $(Get-Date)" | Out-File .\logs\access.log
   ```

   **Linux/Mac:**
   ```bash
   mkdir -p logs
   echo "Log entry 1 - $(date)" > logs/app.log
   echo "Log entry 2 - $(date)" > logs/access.log
   ```

2. En S3, hacer clic en **Create folder**
   - **Folder name:** `logs`
   - Hacer clic en **Create folder**

3. Entrar a la carpeta `logs` y subir los archivos `app.log` y `access.log`

**Verificación:**
- Bucket debe mostrar 3 objetos total (1 en raíz + 2 en logs/)
- La estructura debe ser:
  ```
  s3://lab02-appdata-xxx/
  ├── sample-data.txt
  └── logs/
      ├── app.log
      └── access.log
  ```

---

### Paso 3: Explorar Propiedades del Objeto

**Tiempo estimado:** 5 minutos

1. En el bucket, hacer clic en el archivo `sample-data.txt`

2. Revisar la pestaña **Properties**:
   - **Object key:** sample-data.txt
   - **Storage class:** Standard
   - **Size:** 60 bytes
   - **Last modified:** Fecha actual
   - **ETag:** Identificador único del objeto
   - **Version ID:** (vacío si versioning está disabled)

3. Hacer clic en **Open** para descargar el archivo

4. Hacer clic en **Copy URL** para ver la URL del objeto

---

### Paso 4: Habilitar S3 Versioning

**Tiempo estimado:** 5 minutos

1. Volver a la página principal del bucket

2. Ir a la pestaña **Properties**

3. En la sección **Bucket Versioning**, hacer clic en **Edit**

4. Seleccionar **Enable**

5. Hacer clic en **Save changes**

6. **Verificar:** El banner debe mostrar "Versioning is enabled"

7. **Subir nueva versión del archivo:**
   - Entrar al bucket
   - Seleccionar `sample-data.txt`
   - Hacer clic en **Upload** > **Add files**
   - Seleccionar versión modificada del archivo
   - Upload

8. **Ver versiones:**
   - Seleccionar `sample-data.txt`
   - Click en **List versions**
   - Debe mostrar 2 versiones con diferentes Version IDs

---

### Paso 5: Crear Lifecycle Rule para Gestión Automática

**Tiempo estimado:** 15 minutos

#### 5.1 Crear bucket para logs

1. Volver a S3 Dashboard

2. Crear segundo bucket:
   - **Bucket name:** `lab02-logs-<nombre>-<fecha>`
   - **Region:** us-east-1
   - **Versioning:** Enable
   - **Block Public Access:** Enable (mantener bloqueado)

3. Crear estructura de carpetas:
   - Crear carpeta `logs/`
   - Dentro de `logs/`, crear subcarpeta `application/`
   - Subir 3-4 archivos de log de prueba

#### 5.2 Configurar Lifecycle Rule

1. Entrar al bucket `lab02-logs-<nombre>-<fecha>`

2. Ir a la pestaña **Management**

3. Hacer clic en **Create lifecycle rule**

4. **Configurar Lifecycle Rule:**

   #### Step 1: Name and scope
   - **Lifecycle rule name:** `lab02-logs-lifecycle`
   - **Rule scope:** Apply to all objects in the bucket
   - ✓ I acknowledge that this rule will apply to all objects in the bucket

   #### Step 2: Transition actions
   - Hacer clic en **Add transition**
   - Configurar primera transición:
     - ✓ Transition objects after storage class duration
     - **Transition to:** S3 Standard-IA
     - **Days after creation:** `30`
   - Hacer clic en **Add transition** nuevamente
   - Configurar segunda transición:
     - ✓ Transition objects after storage class duration
     - **Transition to:** S3 Glacier Instant Retrieval
     - **Days after creation:** `90`

   #### Step 3: Expiration actions
   - ✓ Expire current versions of objects
   - **Days after creation:** `365`

   #### Step 4: Review
   - Revisar configuración

5. Hacer clic en **Create rule**

**Verificación:** La lifecycle rule debe aparecer en la lista con estado `Enabled`.

---

### Paso 6: Explorar Clases de Almacenamiento

**Tiempo estimado:** 5 minutos

1. En el bucket `lab02-appdata-<nombre>-<fecha>`, seleccionar `sample-data.txt`

2. Hacer clic en **Actions** > **Change storage class**

3. Explorar las opciones disponibles:
   - **S3 Standard:** General purpose, frequently accessed
   - **S3 Standard-IA:** Infrequent access, lower cost per GB
   - **S3 Glacier Instant Retrieval:** Archive, instant access, lowest cost
   - **S3 Glacier Flexible Retrieval:** Archive, minutes to hours retrieval
   - **S3 Glacier Deep Archive:** Longest-term archive, 12+ hours retrieval
   - **S3 Intelligent-Tiering:** Auto-optimizes based on access patterns

4. Cambiar el storage class a **S3 Standard-IA** para ver cómo funciona

5. **Verificar:** El objeto ahora muestra `Standard-IA` como storage class

---

### Paso 7: Explorar S3 con AWS CLI (Opcional)

**Tiempo estimado:** 15 minutos

#### 7.1 Configurar AWS CLI (si no está configurado)

```bash
aws configure
# AWS Access Key ID: [tu access key]
# AWS Secret Access Key: [tu secret key]
# Default region name: us-east-1
# Default output format: json
```

#### 7.2 Comandos S3 básicos

```bash
# Listar todos los buckets
aws s3 ls

# Listar objetos en un bucket
aws s3 ls s3://lab02-appdata-xxx/

# Listar objetos recursivamente
aws s3 ls s3://lab02-appdata-xxx/ --recursive

# Subir archivo
aws s3 cp sample-data.txt s3://lab02-appdata-xxx/

# Subir carpeta completa
aws s3 cp logs/ s3://lab02-appdata-xxx/logs/ --recursive

# Descargar archivo
aws s3 cp s3://lab02-appdata-xxx/sample-data.txt ./

# Sincronizar carpeta local con bucket
aws s3 sync ./logs s3://lab02-logs-xxx/logs/

# Eliminar objeto
aws s3 rm s3://lab02-appdata-xxx/sample-data.txt

# Eliminar todos los objetos (precaución)
aws s3 rm s3://lab02-appdata-xxx/ --recursive
```

#### 7.3 Explorar lifecycle con CLI

```bash
# Ver lifecycle rules de un bucket
aws s3api get-bucket-lifecycle-configuration --bucket lab02-logs-xxx

# Ver versioning status
aws s3api get-bucket-versioning --bucket lab02-appdata-xxx
```

---

## Criterios de Verificación

Al completar este laboratorio, el estudiante debe ser capaz de:

- [ ] Crear un bucket S3 con configuración apropiada
- [ ] Subir objetos individuales via Console
- [ ] Subir carpetas y estructura de directorios
- [ ] Habilitar y usar S3 Versioning
- [ ] Ver diferentes versiones de un objeto
- [ ] Crear lifecycle rules para transición automática
- [ ] Configurar transición a S3 Standard-IA después de 30 días
- [ ] Configurar transición a S3 Glacier después de 90 días
- [ ] Configurar expiración de objetos después de 365 días
- [ ] Cambiar storage class de objetos individuales
- [ ] Listar buckets y objetos usando AWS CLI
- [ ] Subir y descargar archivos usando AWS CLI
- [ ] Entender las diferencias entre clases de almacenamiento S3
- [ ] Calcular costos aproximados usando la calculadora de S3

---

## Limpieza de Recursos

** IMPORTANTE:** Al finalizar el laboratorio:

1. **Eliminar objetos de los buckets:**
   ```bash
   # Empty buckets antes de eliminar
   aws s3 rm s3://lab02-appdata-xxx --recursive
   aws s3 rm s3://lab02-logs-xxx --recursive
   ```

2. **Eliminar buckets:**
   - S3 Dashboard > Seleccionar bucket > Delete

3. **Verificar eliminación:**
   - Confirmar que los buckets ya no aparecen en la lista

---

## Tabla de Comparación de Clases de Almacenamiento

| Clase | Precio GB/mes | Retrieval | Durabilidad | Caso de Uso |
|-------|---------------|-----------|--------------|-------------|
| **Standard** | $0.023 | Instant | 99.999999999% | Hot data, activos frecuentes |
| **Standard-IA** | $0.0125 | Instant | 99.999999999% | Cool data,访问 menos frecuente |
| **Glacier Inst.** | $0.004 | Instant | 99.999999999% | Archive, compliance |
| **Glacier Flex.** | $0.004 + $0.03/GB retrieval | Minutos/horas | 99.999999999% | Archive, backup |
| **Deep Archive** | $0.00099 | 12+ horas | 99.999999999% | Long-term retention |
| **Intelligent** | $0.0125 + $0.00025/1000 objs | Auto | 99.999999999% | Access patterns impredecibles |

---

## Errores Comunes y Soluciones

| Error | Causa | Solución |
|-------|-------|----------|
| `Bucket name already exists` | Nombre duplicado globalmente | Usar nombre único con prefijos personales |
| `Access Denied` | Permisos IAM insuficientes | Verificar usuario tiene permisos s3:* |
| `InvalidToken` | Credenciales AWS CLI inválidas | Ejecutar `aws configure` nuevamente |
| Objeto no cambia de storage class | Lifecycle rule no habilitada | Verificar que la regla está enabled |
| No se puede hacer upload | Bucket lleno o límite alcanzado | Request limit increase o cleanup |
| URL de objeto no funciona | Bucket bloquea acceso público | Usar signed URLs o verificar ACLs |

---

## Referencias

- [Amazon S3 Documentation](https://docs.aws.amazon.com/s3/latest/userguide/)
- [S3 Storage Classes](https://docs.aws.amazon.com/AmazonS3/latest/userguide/storage-class-intro.html)
- [S3 Lifecycle Configuration](https://docs.aws.amazon.com/AmazonS3/latest/userguide/object-lifecycle-mgmt.html)
- [S3 Versioning](https://docs.aws.amazon.com/AmazonS3/latest/userguide/Versioning.html)
- [AWS CLI S3 Commands](https://docs.aws.amazon.com/cli/latest/reference/s3/)
