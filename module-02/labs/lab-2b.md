# Lab 2.2.b: Gestión de AMIs - Creación, Versionado, Copia y Compartición

## Objetivo

Aprender a crear AMIs personalizadas desde instancias configuradas, versionarlas, replicarlas entre regiones y compartir entre cuentas AWS. Este laboratorio demuestra el concepto de Golden Images y cómo gestionar el ciclo de vida de imágenes de instancias.

---

## Duración Estimada

**75 minutos**

---

## Prerrequisitos

- Lab 2.1 completado (`lab02-vpc` con subnets públicas y privadas)
- Lab 2.2 completado (instancia `lab02-webserver` con Apache funcionando)
- Credenciales AWS con permisos para EC2, AMI
- Segunda cuenta AWS (para Paso 4) o Account ID de compañero de laboratorio

---

## Recursos

- EC2 Dashboard en AWS Console
- AMI Management en EC2 Dashboard
- AWS Account ID (para compartición)

---

## Arquitectura Objetivo

```
us-east-1 (N. Virginia)                us-west-2 (Oregon)
┌─────────────────────────┐           ┌─────────────────────────┐
│ lab02-ami-webserver-v1  │           │ lab02-ami-webserver-v2  │
│ lab02-ami-webserver-v2  │──Copy AMI→│   (copia)               │
│                         │           │                         │
│ AMI compartida ───────Share AMI────→│ Cuenta secundaria       │
└─────────────────────────┘           └─────────────────────────┘
```

---

## Aplicación Web de Prueba

La aplicación web es HTML básico servido por Apache:

**Contenido v1:**
```html
<h1>Bienvenido al Lab 02</h1>
<p>Servidor web publicado exitosamente!</p>
<p>Fecha: [timestamp original]</p>
```

**Contenido v2 (actualizado):**
```html
<h1>Version 2 - Actualizado</h1>
<p>Esta es la versión 2 del servidor web.</p>
<p>Fecha: [timestamp nuevo]</p>
```

---

## Pasos

### Paso 1: Crear AMI personalizada (v1)

**Tiempo estimado:** 15 minutos

En este paso, crearás una AMI desde la instancia `lab02-webserver` que configuraste en el Lab 2.2.

1. Verificar que la instancia `lab02-webserver` está corriendo y la aplicación web funciona:

   ```bash
   # En AWS Console, verificar que la instancia tiene estado "Running"
   # Obtener la IP pública desde EC2 Dashboard > Instances
   ```

2. Abrir la consola de AWS y navegar a **EC2 Dashboard**

3. En el menú lateral izquierdo, seleccionar **Instances**

4. Seleccionar la instancia `lab02-webserver` (checkbox a la izquierda)

5. En el menú **Actions**, expandir **Image and templates**

6. Hacer clic en **Create image**

7. **Configurar la AMI:**
   - **Image name:** `lab02-ami-webserver-v1`
   - **Image description:** `Web server Apache - Lab 2.2 - Version 1`
   - **No reboot:** Dejar desmarcado (recommended — la instancia se reinicia para garantizar consistencia del filesystem)

8. Hacer clic en **Create image**

9. **Verificación:**
   - Aparece notificación con el AMI ID (ejemplo: `ami-0a1234567890abcde`)
   - Hacer clic en **Close** o ir a **AMIs** en el menú lateral
   - La AMI aparece con estado `pending` (puede tomar 2-5 minutos)
   - Cuando cambia a `available`, la AMI está lista para usar

10. **Registrar el AMI ID** para referencia:
    ```
    AMI ID v1: ami-XXXXXXXX
    ```

---

### Paso 2: Versionar AMI (Crear v2)

**Tiempo estimado:** 20 minutos

En este paso, actualizarás el contenido de la instancia web y crearás una segunda versión de la AMI.

#### 2.1 Actualizar el contenido de la instancia

1. Conectar a `lab02-webserver` por SSH usando contraseña:

   ```bash
   ssh ec2-user@<ip-publica>
   # Contraseña: LabPassword123
   ```

2. Verificar el contenido actual:

   ```bash
   cat /var/www/html/index.html
   ```

3. Actualizar el contenido para simular una nueva versión:

   ```bash
   sudo bash -c 'cat > /var/www/html/index.html << EOF
   <html>
   <head><title>Lab 02 - EC2 Web Server v2</title></head>
   <body>
     <h1>Version 2 - Actualizado</h1>
     <p>Esta es la version 2 del servidor web.</p>
     <p>Fecha: $(date)</p>
   </body>
   </html>
   EOF'
   ```

4. Verificar que Apache sirve el contenido actualizado:

   ```bash
   curl localhost
   ```

5. Detener la instancia (no terminarla):

   ```bash
   sudo systemctl stop httpd
   sudo shutdown -h now
   ```

6. En AWS Console, esperar a que el estado de la instancia cambie a `Stopped`

#### 2.2 Crear AMI v2

1. En EC2 Dashboard > Instances, seleccionar `lab02-webserver` (ya detenida)

2. En **Actions** > **Image and templates**, hacer clic en **Create image**

3. **Configurar:**
   - **Image name:** `lab02-ami-webserver-v2`
   - **Image description:** `Web server Apache - Lab 2.2 - Version 2`
   - **No reboot:** Desmarcado

4. Hacer clic en **Create image**

5. **Esperar** a que el estado cambie a `available`

#### 2.3 Comparar y probar las versiones

1. En el menú lateral, ir a **AMIs** bajo **Images**

2. Verificar que ambas AMIs aparecen:
   - `lab02-ami-webserver-v1` (original)
   - `lab02-ami-webserver-v2` (actualizada)

3. **Comparar detalles:**
   - Seleccionar cada AMI y revisar:
     - **Creation date:** Timestamp diferente
     - **Source instance:** Misma instancia origen
     - **Snapshot ID:** Diferentes snapshots

4. **Probar lanzando instancias desde cada AMI:**

   a. Seleccionar `lab02-ami-webserver-v1`
   
   b. **Actions** > **Launch instance from AMI**
   
   c. Configurar:
      - **Name:** `lab02-test-v1`
      - **Instance type:** `t3.micro`
      - **Network:** `lab02-vpc`
      - **Subnet:** `lab02-subnet-publica`
      - **Auto-assign public IP:** Enable
      - **Security Group:** `lab02-sg-bastion`
      - **Key pair:** `lab02-keypair`

   d. Hacer clic en **Launch instance**

   e. Repetir para `lab02-ami-webserver-v2` con nombre `lab02-test-v2`

5. **Verificar contenido:**
   - Obtener IPs públicas de ambas instancias
   - Abrir navegador hacia cada IP
   - **lab02-test-v1:** Muestra contenido original "Bienvenido al Lab 02"
   - **lab02-test-v2:** Muestra contenido nuevo "Version 2 - Actualizado"

---

### Paso 3: Copiar AMI a otra región

**Tiempo estimado:** 20 minutos

En este paso, copiarás la AMI v2 a la región us-west-2 (Oregon) para demostrar replicación geográfica.

1. En el menú lateral, ir a **AMIs** bajo **Images**

2. Seleccionar `lab02-ami-webserver-v2` (checkbox)

3. En **Actions**, hacer clic en **Copy AMI**

4. **Configurar la copia:**
   - **Source AMI region:** US East (N. Virginia) - us-east-1 (auto-detectado)
   - **Destination region:** US West (Oregon) - us-west-2
   - **Destination AMI name:** `lab02-ami-webserver-v2-oregon`
   - **Destination AMI description:** `Web server Apache - Lab 2.2 v2 - Copia a Oregon`
   - **Encryption:** Dejar desmarcado (mantener sin encriptar para simplificar)

5. Hacer clic en **Copy AMI**

6. **Verificación:**
   - Aparece notificación de que la copia inizi
   - El AMI ID de la copia será diferente (ejemplo: `ami-0bcdef1234567890`)
   - Copiar el **Destination AMI ID** mostrado

7. **Cambiar a la región destino:**
   - En la barra superior de AWS Console, hacer clic en el selector de región (lado superior derecho)
   - Cambiar a **US West (Oregon)**

8. En la nueva región, ir a **EC2 Dashboard** > **AMIs**

9. **Verificar** que la AMI copiada aparece con estado `available`

10. **Lanzar instancia en Oregon:**
    - Seleccionar la AMI copiada
    - **Actions** > **Launch instance from AMI**
    - Configurar:
      - **Name:** `lab02-oregon-test`
      - **Instance type:** `t3.micro`
      - **VPC:** Usar VPC con mismo CIDR en us-west-2 (o crear una básica)
      - **Subnet:** Subnet pública
      - **Security Group:** Permita HTTP (80) y SSH (22)
      - **Key pair:** Key pair existente o crear nuevo

11. **Verificar:**
    - Obtener IP pública de la instancia en Oregon
    - Acceder por navegador
    - Verificar que muestra contenido de v2

---

### Paso 4: Compartir AMI entre cuentas

**Tiempo estimado:** 15 minutos

En este paso, compartirás la AMI con una segunda cuenta AWS. Esto es común en organizaciones donde un equipo central proporciona imágenes base a otros equipos.

#### 4.1 Obtener el Account ID de la cuenta destino

1. En la segunda cuenta AWS:
   - Ir a **AWS Console**
   - En la barra superior derecha, hacer clic en el nombre de cuenta
   - Seleccionar **My Account**
   - Copiar el **AWS Account ID** (12 dígitos)

2. **Anotar:** `ACCOUNT_ID_DESTINO` (ejemplo: `111122223333`)

#### 4.2 Compartir la AMI

1. **Volver a la cuenta origen** (us-east-1)

2. Ir a **EC2 Dashboard** > **AMIs**

3. Seleccionar `lab02-ami-webserver-v2`

4. En **Actions**, hacer clic en **Edit permissions**

5. En la sección **Shared accounts**, hacer clic en **Add permissions**

6. Ingresar el AWS Account ID de la cuenta destino:
   - **AWS Account ID:** `111122223333`

7. Hacer clic en **Save**

8. **Verificación:**
   - En "Shared accounts" debe aparecer el Account ID
   - El permiso indica "Allow"

#### 4.3 Usar AMI en la cuenta destino

1. En la **cuenta destino** (`111122223333`):

2. Ir a **EC2 Dashboard** > **AMIs**

3. En el filtro **Owned by me**, cambiar a **Shared with me**

4. La AMI `lab02-ami-webserver-v2` debe aparecer como **Shared from account: 111122223333** (o el ID de la cuenta origen)

5. **Verificar:** El estado debe ser `Available`

6. **Lanzar instancia:**
   - Seleccionar la AMI compartida
   - **Actions** > **Launch instance from AMI**
   - Configurar como en pasos anteriores
   - La instancia arrancará correctamente

7. **Verificar acceso web:**
   - Obtener IP pública
   - Acceder por navegador
   - Confirmar que la aplicación funciona

---

## Criterios de Verificación

Al completar este laboratorio, el estudiante debe ser capaz de:

- [ ] Crear una AMI personalizada desde una instancia EC2 existente
- [ ] Entender la diferencia entre detener vs terminar una instancia
- [ ] Crear múltiples versiones de una AMI (v1 y v2)
- [ ] Comparar AMIs por timestamp y source instance
- [ ] Lanzar instancias desde AMIs de diferentes versiones
- [ ] Verificar que el contenido de la aplicación refleja la versión de la AMI
- [ ] Copiar una AMI a otra región de AWS
- [ ] Verificar que la AMI copiada funciona en la nueva región
- [ ] Compartir una AMI con otra cuenta AWS
- [ ] Lanzar una instancia desde una AMI compartida en otra cuenta

---

## Arquitectura Final

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Cuenta Origen (us-east-1)                    │
│                                                                      │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                 │
│  │ lab02-test  │  │ lab02-test  │  │ lab02-      │                 │
│  │ -v1         │  │ -v2         │  │ webserver   │                 │
│  │ (desde v1)  │  │ (desde v2)  │  │ (stopped)    │                 │
│  └─────────────┘  └─────────────┘  └─────────────┘                 │
│                                                                      │
│  ┌─────────────────────────────────────────────────────┐             │
│  │ AMIs                                                     │             │
│  │  lab02-ami-webserver-v1  ──────────────────────────── AMI copiada │
│  │  lab02-ami-webserver-v2  ──Share──→ AMI compartida     │             │
│  └─────────────────────────────────────────────────────┘             │
└─────────────────────────────────────────────────────────────────────┘
              │
              │ Copy AMI (v2)
              ↓
┌─────────────────────────────────────────────────────────────────────┐
│                      Cuenta Destino (us-west-2)                      │
│                                                                      │
│  ┌─────────────────────────────────────────────────────┐             │
│  │ lab02-ami-webserver-v2-oregon (AMI copiada)          │             │
│  │ lab02-oregon-test (instancia desde AMI copiada)      │             │
│  └─────────────────────────────────────────────────────┘             │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│                    Cuenta Secundaria (111122223333)                  │
│                                                                      │
│  ┌─────────────────────────────────────────────────────┐             │
│  │ AMI compartida (desde cuenta origen)                │             │
│  │ Instancia desde AMI compartida                     │             │
│  └─────────────────────────────────────────────────────┘             │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Limpieza de Recursos

** IMPORTANTE:** Al finalizar el laboratorio, eliminar los recursos creados para evitar costos continuos:

### En us-east-1 (Cuenta Origen)

1. **Terminar instancias de prueba:**
   - EC2 Dashboard > Instances
   - Seleccionar: `lab02-test-v1`, `lab02-test-v2`
   - **Instance state** > **Terminate instance**

2. **Iniciar instancia original si está detenida:**
   - Si `lab02-webserver` está detenida y quieres conservarla:
     - Seleccionar > **Instance state** > **Start**

3. **Deregistrar AMIs:**
   - EC2 Dashboard > AMIs
   - Seleccionar: `lab02-ami-webserver-v1`, `lab02-ami-webserver-v2`
   - **Actions** > **Deregister AMI**
   - Confirmar deregistro

4. **Eliminar snapshots:**
   - EC2 Dashboard > **Snapshots** bajo **Elastic Block Store**
   - Seleccionar los snapshots asociados a las AMIs deregistradas
   - **Actions** > **Delete snapshot**

### En us-west-2 (Oregon)

5. **Terminar instancia de prueba:**
   - `lab02-oregon-test` > Terminate

6. **Deregistrar AMI copiada:**
   - `lab02-ami-webserver-v2-oregon` > Deregister AMI

7. **Eliminar snapshot copiado:**
   - Eliminar snapshot asociado

### En Cuenta Secundaria

8. **Terminar instancia:**
   - Terminar cualquier instancia creada desde AMI compartida

---

## Errores Comunes y Soluciones

| Error | Causa | Solución |
|-------|-------|----------|
| AMI en estado `failed` | Instancia no estaba detenida al crear AMI, o volumen corrupto | Verificar estado de instancia, recrear AMI |
| No aparece AMI compartida en cuenta destino | Filtro incorrecto o permisos no guardados | Cambiar filtro a "Shared with me", verificar permisos |
| Instancia desde AMI compartida no inicia | Security groups no permiten tráfico | Seleccionar SG que permita HTTP/SSH |
| Copy AMI falla | Límite de almacenamiento en región destino | Verificar límites de EBS en región destino |
| AMI compartida no visible | Cuenta ID incorrecta | Verificar Account ID de 12 dígitos |

---

## Referencias

- [Amazon EC2 AMI Documentation](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/AMIs.html)
- [Copying an AMI](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/CopyingAMIs.html)
- [Sharing an AMI with Specific AWS Accounts](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/sharingamis-explicit.html)
- [AWS Regions and Endpoints](https://docs.aws.amazon.com/general/latest/gr/rande.html)
