# Lab 2.2: Provisión de Instancias EC2 con EBS

## Objetivo

Lanzar instancias EC2 utilizando diferentes métodos (Launch Instance directo y Launch Template), configurar almacenamiento EBS (volúmenes raíz y adicionales), implementar un bastion host para acceso seguro, y publicar una aplicación web básica en Apache.

---

## Duración Estimada

**75 minutos**

---

## Prerrequisitos

- Cuenta AWS activa con acceso a EC2 y VPC
- VPC del Lab 2.1 completada (`lab02-vpc` con subnets públicas y privadas)
- Security Groups configurados (`lab02-sg-bastion` y `lab02-sg-privada`)
- Conocimientos básicos de SSH y línea de comandos Linux

---

## Arquitectura Objetivo

```
┌─────────────────────────────────────────────────────────────┐
│                        VPC (10.0.0.0/16)                    │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              Subnet Pública (10.0.1.0/24)            │   │
│  │   ┌─────────────┐  ┌─────────────┐                 │   │
│  │   │  EC2 Bastion │  │ EC2 Web     │                 │   │
│  │   │  (SSH)       │  │ Server      │                 │   │
│  │   └─────────────┘  └─────────────┘                 │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              Subnet Privada (10.0.2.0/24)            │   │
│  │   ┌─────────────┐                                   │   │
│  │   │  EC2 App     │                                   │   │
│  │   │  Server      │                                   │   │
│  │   └─────────────┘                                   │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                              │
│  EBS Volume adicional en Web Server                          │
└─────────────────────────────────────────────────────────────┘
```

---

## Recursos

- EC2 Dashboard en AWS Console
- Amazon Linux 2 AMI (Free tier eligible)
- Maximum Instances por tipo y región
- Límites de volúmenes EBS

---

## Pasos

### Paso 1: Crear un Key Pair

**Tiempo estimado:** 5 minutos

1. Abrir la consola de AWS y navegar a **EC2 Dashboard**

2. En el menú lateral, seleccionar **Key Pairs** bajo **Network & Security**

3. Hacer clic en **Create key pair**

4. Configurar:
   - **Name:** `lab02-keypair`
   - **Key pair type:** RSA
   - **Private key file format:** `.pem` (para Linux/Mac) o `.ppk` (para Windows PuTTY)

5. Hacer clic en **Create key pair**

6. **Descarga automática:** El navegador descargará el archivo `lab02-keypair.pem`

7. **Guardar el archivo:**
   - Linux/Mac: Mover a `~/.ssh/` y cambiar permisos: `chmod 400 ~/.ssh/lab02-keypair.pem`
   - Windows: Guardar en ubicación segura (ej: `C:\Users\<tu_usuario>\keys\`)

**Verificación:** Confirmar que el key pair aparece en la lista con fingerprint SHA-1.

---

### Paso 2: Crear un Launch Template

**Tiempo estimado:** 15 minutos

1. En el menú lateral de EC2 Dashboard, seleccionar **Launch Templates**

2. Hacer clic en **Create launch template**

3. **Configurar Launch Template:**

   #### 3.1 Información del Template
   - **Launch template name:** `lab02-lt-webserver`
   - **Template version description:** `Version 1 - Web Server`
   - **Auto Scaling guidance:** ✓ Provide guidance

   #### 3.2 AMI Selection
   - **Amazon Machine Image (AMI):** Buscar y seleccionar `Amazon Linux 2023023 AMI`
   - Verificar que sea `x86_64` y el tipo sea `HVM`

   #### 3.3 Instance Type
   - **Instance type:** `t3.micro` (o `t3.small` si se desea más capacidad)

   #### 3.4 Network Settings
   - **Networking platform:** Virtual Private Cloud (VPC)
   - **VPC:** `lab02-vpc`
   - **Subnet:** No subnet (required for Auto Scaling)
   - **Auto-assign public IP:** Enabled (subnet default)

   #### 3.5 Security Groups
   - **Security groups:** Seleccionar `lab02-sg-bastion` (para testing inicial)

   #### 3.6 Storage (Volume)
   - **Volume 1 (Root):**
     - Device: `/dev/xvda`
     - AMI Size: 8 GiB (ya viene con la AMI)
     - Volume Type: General Purpose SSD (gp3)
     - Encrypted: No (para este lab)

   #### 3.7 Advanced Details > User Data
   Pegar el siguiente script para automatizar la instalación de Apache:

   ```bash
   #!/bin/bash
   dnf update -y
   dnf install -y httpd
   systemctl start httpd
   systemctl enable httpd
   echo "<html><head><title>Lab 02 - EC2 Web Server</title></head>" > /var/www/html/index.html
   echo "<body><h1>Bienvenido al Lab 02</h1>" >> /var/www/html/index.html
   echo "<p>Servidor web publicado exitosamente!</p>" >> /var/www/html/index.html
   echo "<p>Fecha: $(date)</p>" >> /var/www/html/index.html
   echo "</body></html>" >> /var/www/html/index.html
   ```

4. Hacer clic en **Create launch template**

**Verificación:** Confirmar que el Launch Template aparece en la lista con estado `Active`.

---

### Paso 3: Lanzar Instancia Bastion Host

**Tiempo estimado:** 10 minutos

1. En EC2 Dashboard, hacer clic en **Launch instance**

2. **Configurar:**
   - **Name:** `lab02-bastion`
   - **AMI:** Amazon Linux 2023023 (debe estar pre-seleccionado)
   - **Instance type:** `t3.micro`
   - **Key pair:** `lab02-keypair`

3. **Configurar Red:**
   - **Network:** `lab02-vpc`
   - **Subnet:** `lab02-subnet-publica`
   - **Auto-assign public IP:** Enable
   - **Firewall (Security Groups):** Seleccionar `lab02-sg-bastion`

4. **Configurar Storage:**
   - **Root volume:** 8 GiB, gp3

5. **Expandir detalles de Advanced Network:**
   - **User data:** Dejar vacío (no necesita script)

6. Hacer clic en **Launch instance**

7. **Verificación:**
   - Confirmar que la instancia aparece en la lista con estado `running`
   - Anotar la **IPv4 pública** del bastion (ej: `54.123.45.67`)

---

### Paso 4: Lanzar Instancia Web Server desde Launch Template

**Tiempo estimado:** 10 minutos

1. Seleccionar el Launch Template `lab02-lt-webserver`

2. Hacer clic en **Actions** > **Launch instance from template**

3. **Ajustar configuración específica:**
   - **Name:** `lab02-webserver`
   - **Number of instances:** 1
   - **Subnet:** `lab02-subnet-publica` (seleccionar del dropdown)
   - **Key pair:** `lab02-keypair`

4. Hacer clic en **Launch instance**

5. **Verificación:**
   - Confirmar que `lab02-webserver` aparece con estado `running`
   - Anotar la **IPv4 pública** del web server

---

### Paso 5: Verificar el Servidor Web

**Tiempo estimado:** 10 minutos

#### 5.1 Verificar desde la Consola AWS

1. En EC2 Dashboard > Instances, seleccionar `lab02-webserver`

2. En la pestaña **Details**, verificar:
   - Instance state: `Running`
   - Public IPv4 address: Anotada
   - Security groups: `lab02-sg-bastion`

3. En la pestaña **Storage**, verificar el volumen raíz

#### 5.2 Verificar desde el Navegador

1. Abrir un navegador web

2. Ingresar: `http://<ip-publica-webserver>`

3. **Esperar 2-3 minutos** para que el User Data se ejecute completamente

4. **Verificar contenido:** Debe aparecer la página "Bienvenido al Lab 02" con la fecha actual

#### 5.3 Verificar desde Terminal (opcional)

1. Conectar al bastion:
   ```bash
   ssh -i ~/.ssh/lab02-keypair.pem ec2-user@<ip-bastion>
   ```

2. Desde el bastion, conectar al web server:
   ```bash
   ssh -i ~/.ssh/lab02-keypair.pem ec2-user@<ip-privada-webserver>
   ```

3. En el web server, verificar Apache:
   ```bash
   sudo systemctl status httpd
   curl localhost
   ```

---

### Paso 6: Crear y Adjuntar Volumen EBS Adicional

**Tiempo estimado:** 15 minutos

#### 6.1 Crear el Volumen EBS

1. En el menú lateral de EC2 Dashboard, seleccionar **Volumes** bajo **Elastic Block Store**

2. Hacer clic en **Create volume**

3. Configurar:
   - **Volume type:** General Purpose SSD (gp3)
   - **Size (GiB):** `10`
   - **Availability Zone:** `us-east-1a` (debe ser la misma que la del web server)
   - **Encryption:** Not encrypted (para este lab)

4. Hacer clic en **Create volume**

5. **Verificación:** El volumen debe aparecer con estado `available`

#### 6.2 Adjuntar el Volumen a la Instancia

1. Seleccionar el volumen recién creado

2. Hacer clic en **Actions** > **Attach volume**

3. Configurar:
   - **Instance:** Seleccionar `lab02-webserver` (instance ID)
   - **Device name:** `/dev/sdf` (nombre del dispositivo sugerido)

4. Hacer clic en **Attach volume**

5. **Verificación:** El volumen debe cambiar a estado `in-use` y mostrar el instance ID

#### 6.3 Formatear y Montar el Volumen en la Instancia

1. Conectar a `lab02-webserver` via SSH:
   ```bash
   ssh -i ~/.ssh/lab02-keypair.pem ec2-user@<ip-publica-webserver>
   ```

2. Verificar que el volumen está disponible:
   ```bash
   lsblk
   # En instancias con controlador Nitro (t3, t4g, m5, etc.), el volumen
   # aparecerá como nvme1n1 (no como xvdf).
   # En instancias Xen antiguas puede aparecer como xvdf.
   ```

3. Formatear el volumen (ajustar el nombre según lsblk):
   ```bash
   # Instancias Nitro:
   sudo mkfs -t xfs /dev/nvme1n1
   # Instancias Xen:
   # Formatear el volumen (ajustar el nombre según lsblk):
   ```bash
   # Instancias Nitro:
   sudo mkfs -t xfs /dev/nvme1n1
   # Instancias Xen:
   # sudo mkfs -t xfs /dev/xvdf
   ```

4. Crear punto de mo (ajustar según el nombre detectado por `lsblk`):
   ```bash
   # Instancias Nitro:
   sudo mount /dev/nvme1n1 /data
   # Instancias Xen:
   # sudo mount /dev/xvdf /data
   ```

6. Verificar montaje:
   ```bash
   df -h
   # Debe mostrar el nuevo disco montado en /data
   ```

7. **(Opcional) Montaje persistente:** Agregar entrada a `/etc/fstab` (usar el nombre correcto según lsblk):
   ```bash
   # Nitro:
   echo "/dev/nvme1n1 /data xfs defaults,noatime 0 2" | sudo tee -a /etc/fstab
   # Xen:
   # Verificar montaje:
   ```bash
   df -h
   # Debe mostrar el nuevo disco montado en /data
   ```

7. **(Opcional) Montaje persistente:** Agregar entrada a `/etc/fstab` (usar el nombre correcto según lsblk):
   ```bash
   # Nitro:
   echo "/dev/nvme1n1 /data xfs defaults,noatime 0 2" | sudo tee -a /etc/fstab
   # Xen:
   # echo "/dev/xvdf /data xfs defaults,noatime 0 2" | sudo tee -a /etc/fstab
   ```

**Verificación:**
- `lsblk` muestra el nuevo disco
- `df -h` muestra `/data` con 10 GiB disponible
- Los datos persisten al reiniciar (con /etc/fstab configurado)

---

### Paso 7: Configurar Permisos para Acceso Web

**Tiempo estimado:** 5 minutos

1. **Modificar Security Group del Web Server:**

   a. Ir a EC2 Dashboard > Instances > `lab02-webserver`
   
   b. En la pestaña **Security**, hacer clic en el Security Group `lab02-sg-bastion`
   
   c. En la página del Security Group, ir a **Edit inbound rules**
   
   d. Agregar regla:
      - **Type:** HTTP (80)
      - **Source:** Anywhere-IPv4 (`0.0.0.0/0`)
   
   e. Guardar规则

2. **Verificar acceso web:**
   - Abrir navegador: `http://<ip-publica-webserver>`
   - La página debe seguir visible

---

### Paso 8: Exploración Adicional (Opcional)

**Tiempo estimado:** 5 minutos

1. **Crear Snapshot del volumen EBS:**
   - Volumes > Seleccionar volumen `/dev/sdf` > Actions > Create snapshot
   - Nombre: `lab02-snapshot-datavolume`

2. **Crear nuevo volumen desde Snapshot:**
   - Snapshots > Seleccionar snapshot > Actions > Create volume
   - Verificar que permite recrear volúmenes

3. **Monitorear con CloudWatch:**
   - EC2 Dashboard > Instances > `lab02-webserver` > Monitoring
   - Ver métricas de CPU, Network, etc.

---

## Criterios de Verificación

Al completar este laboratorio, el estudiante debe ser capaz de:

- [ ] Crear un Key Pair para autenticación SSH
- [ ] Crear un Launch Template con configuración predefinida
- [ ] Lanzar una instancia EC2 desde el Wizard
- [ ] Lanzar una instancia EC2 desde Launch Template
- [ ] Identificar la AMI utilizada y sus características
- [ ] Adjuntar Security Groups a instancias
- [ ] Crear un volumen EBS adicional
- [ ] Adjuntar un volumen EBS a una instancia en ejecución
- [ ] Formatear y montar un volumen EBS en Linux
- [ ] Configurar montaje persistente en `/etc/fstab`
- [ ] Acceder al servidor web via navegador usando IP pública
- [ ] Ejecutar User Data para automatizar configuración
- [ ] Conectar desde bastion a instancias en subnet privada
- [ ] Verificar métricas básicas de la instancia en CloudWatch

---

## Comandos Útiles de Referencia

```bash
# Conexión SSH
ssh -i "lab02-keypair.pem" ec2-user@<ip-publica>

# Ver estado de Apache
sudo systemctl status httpd

# Ver logs de Apache
sudo tail -f /var/log/httpd/access_log
sudo tail -f /var/log/httpd/error_log

# Ver discos y montaje
lsblk
df -h
mount | grep /data

# Ver información de instancia
curl http://169.254.169.254/latest/meta-data/
curl http://169.254.169.254/latest/meta-data/instance-id
curl http://169.254.169.254/latest/meta-data/public-ipv4
```

---

## Limpieza de Recursos

** IMPORTANTE:** Al finalizar el laboratorio, eliminar los recursos creados:

1. **Terminar instancias:**
   - EC2 Dashboard > Instances > Seleccionar `lab02-bastion` y `lab02-webserver` > Instance State > Terminate

2. **Separar y eliminar volumen EBS:**
   - Primero separar si está attached: Volumes > Seleccionar > Actions > Detach volume
   - Luego eliminar: Volumes > Seleccionar > Actions > Delete volume

3. **Eliminar Snapshot (si se creó):**
   - Snapshots > Seleccionar > Actions > Delete

4. **Eliminar Launch Template:**
   - Launch Templates > Seleccionar `lab02-lt-webserver` > Actions > Delete template

5. **Eliminar Key Pair (opcional):**
   - Key Pairs > Seleccionar `lab02-keypair` > Actions > Delete

**No eliminar la VPC ni Security Groups** si se usarán en el Lab 2.4.

---

## Errores Comunes y Soluciones

| Error | Causa | Solución |
|-------|-------|----------|
| `Your keypair doesn't exist` al conectar | Path incorrecto o archivo no encontrado | Verificar path con `ls -la ~/.ssh/lab02-keypair.pem` |
| `Permission denied (publickey)` | Permisos incorrectos en archivo PEM | `chmod 400 ~/.ssh/lab02-keypair.pem` |
| `Connection timed out` | Security Group no permite SSH | Verificar regla inbound en SG |
| User Data no se ejecutó | Instancia tarda en inicializar | Esperar 2-5 minutos y verificar `cloud-init` logs |
| Volumen no aparece en `lsblk` | Zona de disponibilidad diferente | Verificar que volumen y instancia están en misma AZ |
| `mkfs: /dev/xvdf: Unknown filesystem type` | Volumen ya tiene datos | Usar `-f` para forzar o verificar con `file -s /dev/xvdf` |
| Página web no carga | Apache no iniciado o puerto bloqueado | `sudo systemctl start httpd` y verificar SG |

---

## Referencias

- [EC2 Documentation](https://docs.aws.amazon.com/ec2/latest/UserGuide/)
- [Amazon EBS Documentation](https://docs.aws.amazon.com/ebs/latest/userguide/)
- [Launch Templates](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-launch-templates.html)
- [User Data Scripts](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/user-data.html)
- [Instance Metadata](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-instance-metadata.html)
