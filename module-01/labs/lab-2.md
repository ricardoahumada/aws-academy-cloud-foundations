# Lab 1.2: Configuración de AWS CLI y Operaciones Básicas

## Objetivo

Instalar y configurar AWS CLI v2, realizar operaciones básicas de consulta de recursos utilizando la línea de comandos y comprender la estructura general de los comandos de AWS CLI.

**Al completar este lab, el estudiante será capaz de:**
- Instalar y verificar AWS CLI v2 en el sistema
- Configurar credenciales de acceso programmatico
- Verificar la identidad de la cuenta usando AWS Security Token Service
- Listar recursos S3, EC2 y VPC usando AWS CLI
- Acceder a la ayuda y documentación desde la línea de comandos

## Duración estimada

45 minutos

## Prerrequisitos

- Cuenta de AWS activa con permisos IAM (programmatic access)
- Editor de texto instalado (VS Code recomendado)
- Acceso a descargar software (permisos de instalación)

> **Nota:** AWS CLI v2 es un binario auto-contenido y **no requiere Python ni pip** instalados previamente.

---

## Pasos

### Paso 1: Instalar AWS CLI v2 en Windows

1. **Descargar el instalador de AWS CLI v2 para Windows:**
   
   a. Abrir un navegador web
   b. Navegar a: [https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2-windows.html](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2-windows.html)
   c. Buscar la sección "Using the MSI installer" 
   d. Descargar el archivo MSI de 64 bits: `AWSCLIV2.msi`

2. **Ejecutar el instalador:**
   
   a. Navegar a la carpeta de descargas
   b. Hacer doble clic en `AWSCLIV2.msi`
   c. En el asistente de instalación, hacer clic en **"Next"**
   d. Aceptar los términos de la licencia y hacer clic en **"Next"**
   e. Seleccionar la ubicación de instalación (por defecto: `C:\Program Files\Amazon\AWSCLIV2`) o mantener la ubicación predeterminada
   f. Hacer clic en **"Next"** y luego en **"Install"**
   g. Si aparece una solicitud de Control de Cuentas de Usuario (UAC), hacer clic en **"Yes"**
   h. Hacer clic en **"Finish"** al completar la instalación

3. **Verificar la instalación:**

   a. Abrir una nueva ventana de **Command Prompt** (cmd) o **PowerShell**
   b. Ejecutar el siguiente comando:
      ```
      aws --version
      ```
   c. Verificar que la salida muestre `aws-cli/2.x.x` seguido de información adicional

### Paso 2: Obtener Credenciales de Acceso (IAM Access Keys)

1. **Acceder a la consola de IAM:**

   a. Abrir un navegador e ir a: [https://console.aws.amazon.com/iam](https://console.aws.amazon.com/iam)
   b. Iniciar sesión con las credenciales proporcionadas

2. **Navegar al usuario asignado:**

   a. En el panel izquierdo, hacer clic en **"Users"**
   b. Buscar y hacer clic en el nombre del usuario asignado para este lab

3. **Crear Access Key (si no existe):**

   a. Ir a la pestaña **"Security credentials"**
   b. En la sección **"Access keys"**, verificar si ya existe una clave de acceso
   c. Si no hay claves o se requiere crear una nueva:
      - Hacer clic en **"Create access key"**
      - En la ventana modal, seleccionar **"Command Line Interface (CLI)"**
      - Opcional: Agregar una descripción/tag
      - Hacer clic en **"Next"**
      - Hacer clic en **"Create access key"**
   d. **IMPORTANTE**: En este momento, **COPIAR Y GUARDAR** los siguientes datos:
      - **AWS Access Key ID** (ejemplo: AKIAIOSFODNN7EXAMPLE)
      - **AWS Secret Access Key** (ejemplo: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY)
   e. **ADVERTENCIA**: Una vez cerrada esta ventana, la Secret Access Key NO se podrá recuperar

4. **Verificar los permisos del usuario:**

   a. En la pestaña **"Permissions"**, verificar que el usuario tiene al menos permisos de lectura
   b. Si es necesario, asociar la política `AmazonS3ReadOnlyAccess` o similar para este lab

### Paso 3: Configurar AWS CLI con Credenciales

1. **Abrir Command Prompt o PowerShell**

2. **Ejecutar el comando de configuración:**
   ```
   aws configure
   ```

3. **Ingresar la información solicitada:**
   
   ```
   AWS Access Key ID [None]: AKIAIOSFODNN7EXAMPLE
   AWS Secret Access Key [None]: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
   Default region name [None]: us-east-1
   Default output format [None]: json
   ```

4. **Verificar que los archivos de configuración fueron creados:**

   a. Navegar a la carpeta del perfil de usuario:
      ```
      cd %USERPROFILE%\.aws
      ```
   b. Listar los archivos:
      ```
      dir
      ```
   c. Verificar que existen:
      - `config` - archivo de configuración (región, output format)
      - `credentials` - archivo de credenciales (access keys)

### Paso 4: Verificar la Identidad de la Cuenta

1. **Ejecutar el comando para obtener la identidad del llamador:**
   ```
   aws sts get-caller-identity
   ```

2. **Observar y guardar la respuesta JSON:**
   
   ```json
   {
       "UserId": "AIDAIOSFODNN7EXAMPLE",
       "Account": "123456789012",
       "Arn": "arn:aws:iam::123456789012:user/nombre-usuario"
   }
   ```

3. **Guardar el Account ID** (número de 12 dígitos) para uso posterior en otros labs

4. **Interpretar la respuesta:**
   - `UserId`: Identificador único del usuario en AWS
   - `Account`: ID de la cuenta de AWS
   - `Arn`: Amazon Resource Name completo del usuario

### Paso 5: Listar Recursos S3

1. **Listar todos los buckets S3 en la cuenta:**
   ```
   aws s3 ls
   ```

2. **Observar la salida:**
   - Lista de buckets con su nombre y fecha de creación
   - Si no hay buckets, la salida estará vacía

3. **Listar el contenido de un bucket específico** (reemplazar `nombre-bucket` con un bucket real):
   ```
   aws s3 ls s3://nombre-bucket/
   ```

4. **Listar buckets con formato detallado:**
   ```
   aws s3 ls --output table
   ```

### Paso 6: Listar Regiones y Zonas de Disponibilidad

1. **Listar todas las regiones disponibles de EC2:**
   ```
   aws ec2 describe-regions --output table
   ```

2. **Observar la tabla de regiones:**
   - Endpoint de cada región
   - Nombre de la región
   - Estado (disponible)

3. **Verificar que la región configurada está disponible:**
   ```
   aws ec2 describe-availability-zones --region us-east-1
   ```

### Paso 7: Listar Recursos VPC

1. **Listar las VPCs en la cuenta:**
   ```
   aws ec2 describe-vpcs
   ```

2. **Observar el JSON de respuesta:**
   - Identificar el VpcId de cada VPC
   - Anotar los CIDR blocks asignados

3. **Listar subredes en una VPC específica** (reemplazar `vpc-xxxxxxx` con un VpcId real):
   ```
   aws ec2 describe-subnets --filters "Name=vpc-id,Values=vpc-xxxxxxx"
   ```

4. **Listar Internet Gateways:**
   ```
   aws ec2 describe-internet-gateways
   ```

### Paso 8: Listar Instancias EC2

1. **Listar todas las instancias EC2:**
   ```
   aws ec2 describe-instances
   ```

2. **Filtrar solo instancias running:**
   ```
   aws ec2 describe-instances --filters "Name=instance-state-name,Values=running"
   ```

3. **Usar query para mostrar solo información importante:**
   ```
   aws ec2 describe-instances --query 'Reservations[*].Instances[*].[InstanceId,InstanceType,State.Name,PublicIpAddress]'
   ```

4. **Contar el número de instancias:**
   ```
   aws ec2 describe-instances --query 'length(Reservations[*].Instances[*])'
   ```

### Paso 9: Explorar la Ayuda de AWS CLI

1. **Ver la ayuda general de AWS CLI:**
   ```
   aws help
   ```

2. **Navegar por la ayuda:**
   - Usar las flechas para navegar
   - Presionar `q` para salir
   - Presionar `/` para buscar

3. **Ver la ayuda del servicio S3:**
   ```
   aws s3 help
   ```

4. **Ver ayuda de un comando específico (ls):**
   ```
   aws s3 ls help
   ```

5. **Ver todos los comandos disponibles para un servicio:**
   ```
   aws s3api help
   ```

6. **Ejemplo: Ver ayuda de create-bucket:**
   ```
   aws s3api create-bucket help
   ```

### Paso 10: Operaciones Avanzadas (Actividad Opcional)

**Nota**: Este paso es opcional. Solo proceder si hay tiempo remaining y el instructor lo aprueba.

1. **Crear un bucket S3** (reemplazar `YYYYMMDD` con la fecha actual en formato numérico):
   ```
   aws s3 mb s3://mi-bucket-unico-YYYYMMDD
   ```

2. **Verificar que el bucket fue creado:**
   ```
   aws s3 ls
   ```

3. **Verificar en la consola AWS:**
   - Ir a Services > Storage > S3
   - Confirmar que el bucket aparece en la lista

4. **Eliminar el bucket creado** (para limpieza):
   ```
   aws s3 rb s3://mi-bucket-unico-YYYYMMDD
   ```

---

## Verificación

Al finalizar este lab, el estudiante debe poder demostrar las siguientes competencias:

### Lista de verificación

- [ ] **Instalar AWS CLI v2 correctamente:**
      - El comando `aws --version` muestra la versión 2.x.x

- [ ] **Configurar credenciales con aws configure:**
      - Los archivos `config` y `credentials` fueron creados en `~/.aws/`
      - La región por defecto es `us-east-1`

- [ ] **Verificar identidad con aws sts get-caller-identity:**
      - El comando retorna UserId, Account y Arn válidos
      - El Account ID fue guardado para uso posterior

- [ ] **Listar recursos usando AWS CLI:**
      - `aws s3 ls` - Lista de buckets S3
      - `aws ec2 describe-vpcs` - Lista de VPCs
      - `aws ec2 describe-instances` - Lista de instancias EC2
      - `aws ec2 describe-regions` - Lista de regiones disponibles

- [ ] **Acceder a ayuda desde línea de comandos:**
      - `aws help` muestra la ayuda general
      - `aws [servicio] help` muestra ayuda específica
      - `aws [servicio] [comando] help` muestra ayuda de comando específico

---

## Errores Comunes y Soluciones

| Error | Causa | Solución |
|-------|-------|----------|
| `aws: command not found` | AWS CLI no instalado correctamente o PATH no configurado | 1. Verificar instalación en `C:\Program Files\Amazon\AWSCLIV2`<br>2. Cerrar y abrir nueva terminal<br>3. Verificar que la carpeta está en PATH del sistema |
| `Unable to locate credentials` | Credenciales no configuradas o archivo credentials mal formado | 1. Ejecutar `aws configure` nuevamente<br>2. Verificar que el archivo `credentials` existe en `~/.aws/`<br>3. Verificar formato correcto del archivo |
| `You must specify a region` | No se especificó región y no hay región por defecto configurada | 1. Usar parámetro `--region` en el comando<br>2. O ejecutar `aws configure` y especificar región |
| `Access Denied` | El usuario IAM no tiene permisos para el recurso o acción | 1. Verificar políticas IAM asociadas al usuario<br>2. Contactar al administrador para permisos adecuados |
| `Invalid credentials` | Access Key ID o Secret Access Key incorrectos | 1. Verificar las credenciales en la consola IAM<br>2. Crear nuevas Access Keys si es necesario |
| `Could not connect to the endpoint URL` | Región especificada no existe o no está disponible | 1. Verificar nombre de región con `aws ec2 describe-regions`<br>2. Usar región válida como `us-east-1` |
| `An error occurred (AuthFailure)` | Problema de autenticación general | 1. Verificar fecha y hora del sistema<br>2. Regenerar credenciales<br>3. Verificar que la cuenta no está suspendida |

---

## Comandos de Referencia Rápida

```bash
# Verificar instalación
aws --version

# Configurar AWS CLI
aws configure

# Verificar identidad
aws sts get-caller-identity

# Listar buckets S3
aws s3 ls
aws s3 ls s3://nombre-bucket/

# Listar recursos EC2
aws ec2 describe-instances
aws ec2 describe-vpcs
aws ec2 describe-regions

# Listar métricas de CloudWatch
aws cloudwatch list-metrics

# Ayuda
aws help
aws [servicio] help
aws [servicio] [comando] help
```

---

## Recursos Adicionales

- [AWS CLI Documentation](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-welcome.html)
- [AWS CLI Configuration](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html)
- [AWS STS Get Caller Identity](https://docs.aws.amazon.com/STS/latest/APIReference/API_GetCallerIdentity.html)
- [AWS S3 CLI Commands](https://docs.aws.amazon.com/cli/latest/reference/s3/)
- [AWS EC2 CLI Reference](https://docs.aws.amazon.com/cli/latest/reference/ec2/)

---

## Limpieza

**Nota para el instructor**: Al finalizar el lab, verificar que no se dejaron recursos creados innecesariamente. Si los estudiantes crearon buckets S3 para práctica, asegurar que fueron eliminados.

---

## Nota de Seguridad

**IMPORTANTE**: Las credenciales de AWS (Access Key ID y Secret Access Key) son información sensible. Nunca:
- Subir credenciales a repositorios Git
- Compartir credenciales por email o chat
- Dejar archivos de credenciales en directorios públicos
- Incluir credenciales en screenshots o documentos

Si las credenciales son comprometidas, eliminarlas inmediatamente desde la consola IAM y crear nuevas.
