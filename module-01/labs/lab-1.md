# Lab 1.1: Exploración de la Consola AWS

## Objetivo

Familiarizarse con la consola de administración de AWS, localizar servicios fundamentales y entender la estructura de navegación.

**Al completar este lab, el estudiante será capaz de:**
- Navegar eficientemente por la consola de AWS
- Localizar los servicios core: EC2, S3, VPC, IAM y CloudWatch
- Explorar recursos existentes en cada servicio
- Acceder a la documentación y ayuda desde la consola

## Duración estimada

60 minutos

## Prerrequisitos

- Cuenta de AWS activa con acceso a la consola
- Permisos de solo lectura sobre los servicios de la cuenta
- Navegador web moderno (Chrome, Firefox, Edge o Safari)

---

## Pasos

### Paso 1: Acceso a la Consola AWS

1. Abrir un navegador web y navegar a: [https://console.aws.amazon.com](https://console.aws.amazon.com)

2. Iniciar sesión con las credenciales proporcionadas por el instructor:
   - Ingresar el **Account ID** o alias cuando lo solicite
   - Usar el nombre de usuario y contraseña asignados

3. Una vez autenticado, verificar la **región seleccionada** en la esquina superior derecha
   - Seleccionar **us-east-1 (N. Virginia)** como región de trabajo
   - Hacer clic en el menú desplegable de regiones para ver las disponibles

4. Observar los elementos principales de la barra de navegación:
   - **AWS Logo**: Regresa al dashboard principal
   - **Services**: Menú desplegable con todos los servicios AWS
   - **Search**: Caja de búsqueda para encontrar servicios y recursos
   - **Support**: Centro de soporte y documentación
   - **Account**: Información de la cuenta y preferencias

### Paso 2: Explorar el Dashboard

1. En la página principal (Console Home), observar los **AWS Quicklinks**:
   - Recent services
   - Favorites
   - Recommended for you

2. Identificar las **tarjetas de servicio populares**:
   - Compute: EC2, Lambda
   - Storage: S3
   - Database: RDS
   - Networking: VPC

3. Hacer clic en **"Build a solution"** y explorar las opciones

4. Hacer clic en **"Discover AWS"** para ver tutoriales guiados

### Paso 3: Explorar Servicios de Compute (EC2)

1. En el menú superior, hacer clic en **"Services"**

2. En la categoría **"Compute"**, hacer clic en **"EC2"**

3. En el panel izquierdo, identificar y familiarizarse con las siguientes secciones:
   - **Instances**: Lista de instancias EC2
   - **Instances > Instances**: Vista principal de instancias
   - **AMIs**: Amazon Machine Images disponibles
   - **Elastic Block Store**: Volúmenes y snapshots
   - **Auto Scaling**: Grupos de auto scaling
   - **Load Balancers**: Balanceadores de carga

4. Hacer clic en **"Instances"** en el panel izquierdo

5. Observar las columnas disponibles en la tabla:
   - Instance ID
   - Instance type
   - Availability Zone
   - Status
   - Monitoring

6. Hacer clic en el botón **"Instance state"** para ver las opciones disponibles (sin modificar nada)

7. Explorar la pestaña **"Monitoring"** si hay instancias running

### Paso 4: Explorar Servicios de Storage (S3)

1. Ir a **Services > Storage > S3**

2. En la página de S3, observar:
   - Lista de buckets existentes
   - Región de cada bucket
   - Fecha de creación

3. Hacer clic en el nombre de cualquier bucket disponible para abrirlo

4. Explorar las pestañas en la página del bucket:
   - **Objects**: Lista de archivos almacenados
   - **Properties**: Configuración del bucket (versioning, encryption, etc.)
   - **Permissions**: Permisos de acceso al bucket
   - **Management**: ciclo de vida, métricas, replication

5. Regresar a la lista de buckets haciendo clic en **"Amazon S3"** en el breadcrumbs

6. Hacer clic en **"Create bucket"** (NO guardar, solo explorar el formulario):
   - Observar las opciones de configuración
   - Revisar las configuraciones de Region, Versioning, Encryption
   - Cerrar el formulario sin crear nada

### Paso 5: Explorar Servicios de Networking (VPC)

1. Ir a **Services > Networking & Content Delivery > VPC**

2. En el panel izquierdo, identificar los siguientes elementos:
   - **Your VPCs**: Redes virtuales definidas
   - **Subnets**: Subredes dentro de cada VPC
   - **Route Tables**: Tablas de enrutamiento
   - **Internet Gateways**: Puertas de enlace a Internet
   - **NAT Gateways**: NAT para instancias privadas
   - **Egress-only Internet Gateways**: Para tráfico IPv6
   - **Peering Connections**: Conexiones entre VPCs

3. Hacer clic en **"Your VPCs"** y observar:
   - Lista de VPCs existentes
   - CIDR blocks asignados
   - Número de subredes por VPC

4. Hacer clic en una de las VPCs para ver sus detalles

5. Explorar la pestaña **"Tags"** para ver el etiquetado

6. En el panel izquierdo, hacer clic en **"Subnets"** y observar:
   - Lista de subredes
   - VPC a la que pertenecen
   - Si son públicas o privadas (basado en routes)

7. Hacer clic en **"Route Tables"** y explorar las rutas configuradas

### Paso 6: Explorar IAM (Identity and Access Management)

1. Ir a **Services > Security, Identity & Compliance > IAM**

2. En el panel izquierdo, identificar:
   - **Dashboard**: Resumen del estado de seguridad
   - **Users**: Usuarios de la cuenta
   - **Groups**: Grupos de usuarios
   - **Roles**: Roles asignados a servicios
   - **Policies**: Políticas de permisos
   - **Identity providers**: Proveedores de identidad externos

3. Hacer clic en **"Users"** y observar:
   - Lista de usuarios existentes
   - Fecha del último acceso
   - Permisos asociados

4. Hacer clic en uno de los usuarios para ver sus:
   - Permisos (policies attached)
   - Grupos a los que pertenece
   - Security credentials (MFA, access keys)
   - Activity reciente

5. Regresar a IAM y hacer clic en **"Roles"**

6. Observar los diferentes roles disponibles y los servicios a los que están asociados

### Paso 7: Explorar CloudWatch

1. Ir a **Services > Management & Governance > CloudWatch**

2. En el panel izquierdo, identificar:
   - **Dashboards**: Paneles de monitoreo personalizados
   - **Metrics**: Métricas de servicios AWS
   - **Logs**: Logs de aplicaciones y servicios
   - **Alarms**: Alarmas configuradas
   - **Events**: Eventos y reglas de eventos

3. Hacer clic en **"Metrics"** y explorar:
   - Categorías de métricas por servicio
   - Métricas de EC2: CPU, Network, Disk
   - Métricas de S3: RequestCount, BytesDownloaded

4. Hacer clic en la pestaña **"All metrics"** para ver todas las métricas disponibles

5. Ir a **"Dashboards"** y observar si hay dashboards creados

6. Ir a **"Alarms"** y revisar el estado de cualquier alarma existente

### Paso 8: Explorar Documentacion y Help

1. En la esquina superior derecha, hacer clic en **"Support"**

2. Opciones disponibles:
   - **Documentation**: Documentación oficial de AWS
   - **Knowledge Center**: Artículos de ayuda
   - **Support Center**: Casos de soporte abiertos
   - **AWS re:Post**: Comunidad de AWS

3. Hacer clic en **"Documentation"** para abrir la documentación oficial

4. En la documentación, buscar **"EC2 User Guide"** y explorar brevemente

5. Usar el botón **"Feedback"** en cualquier página para familiarizarse con el mecanismo de feedback

---

## Verificación

Al finalizar este lab, el estudiante debe poder verificar los siguientes conocimientos:

### Lista de verificación

- [ ] **Localizar los 5 servicios core** en el menú de servicios:
      - EC2 (Compute)
      - S3 (Storage)
      - VPC (Networking)
      - IAM (Security)
      - CloudWatch (Management)

- [ ] **Explicar la estructura de navegación** de la consola:
      - Menú Services en la barra superior
      - Panel izquierdo en cada servicio
      - Barra de búsqueda para encontrar servicios
      - Cambio de región

- [ ] **Identificar recursos existentes** en cada servicio:
      - Al menos 2 instancias EC2 (si hay running)
      - Al menos 2 buckets S3 (si hay creados)
      - Al menos 1 VPC con sus subredes
      - Al menos 2 usuarios IAM
      - Al menos 1 dashboard o métricas en CloudWatch

- [ ] **Acceder a documentación** desde la consola:
      - Usar el enlace de Documentation
      - Usar la búsqueda en la documentación

---

## Errores Comunes y Soluciones

| Error | Posible Causa | Solución |
|-------|---------------|----------|
| **"Access Denied"** al intentar ver un recurso | El usuario no tiene permisos de lectura para ese servicio | Verificar con el administrador que el usuario tiene permisos de lectura |
| **No se ven recursos** (tabla vacía) | La región seleccionada no tiene recursos | Cambiar a otra región usando el selector de regiones en la esquina superior derecha |
| **La consola no carga correctamente** | Problemas con el navegador o caché | Abrir en modo incógnito/privado, o limpiar caché del navegador |
| **No aparece la opción del menú** | El servicio puede estar en una categoría diferente | Usar la barra de búsqueda para localizar el servicio |
| **Sesión expira frecuentemente** | Configuración de seguridad de la organización | Contactar al administrador para ajustar políticas de sesión |

---

## Recursos Adicionales

- [AWS Console Getting Started](https://docs.aws.amazon.com/awsconsolehelpdocs/latest/gsg/getting-started.html)
- [AWS Documentation](https://docs.aws.amazon.com/)
- [AWS EC2 Documentation](https://docs.aws.amazon.com/ec2/)
- [AWS S3 Documentation](https://docs.aws.amazon.com/s3/)
- [AWS IAM Documentation](https://docs.aws.amazon.com/iam/)

---

## Nota

Este lab es de carácter exploratorio. NO se debe crear, modificar o eliminar ningún recurso durante la realización de este laboratorio. Todas las acciones se limitan a navegación y lectura de información existente.
