# Lab 3.1: Configuración de IAM con Usuarios, Grupos y Políticas

## Objetivo

Crear una estructura completa de IAM con usuarios para diferentes roles, grupos con políticas apropiadas, roles para servicios AWS y configuración de MFA para usuarios privilegiados.

## Duración estimada

75 minutos

## Prerrequisitos

- Cuenta AWS con permisos de administrador
- Acceso a la consola AWS con usuario root o usuario con permisos administrativos completos
- AWS CLI configurado con credenciales de administrador (opcional para verificación)

## Recursos

- Tiempo aproximado: 75 minutos
- Costo estimado: Este lab usa solo servicios gratuitos de AWS (IAM es gratuito)

---

## Pasos

### Paso 1: Crear Usuarios Individuales

1. En la consola AWS, navegar a **IAM** > **Users** > **Add users**

2. Crear el primer usuario `admin-juan`:
   - **User name**: `admin-juan`
   - Marcar **Provide user access to the AWS Management Console**
   - **Console password**: Custom (generar contraseña segura)
   - Desmarcar **Users must create a new password at next sign-in**

3. Crear el segundo usuario `dev-maria`:
   - **User name**: `dev-maria`
   - Marcar **Provide user access to the AWS Management Console**
   - **Console password**: Custom

4. Crear el tercer usuario `analyst-pedro`:
   - **User name**: `analyst-pedro`
   - Marcar **Provide user access to the AWS Management Console**
   - **Console password**: Custom

5. Crear el cuarto usuario `app-service`:
   - **User name**: `app-service`
   - **No** marcar acceso a consola (sólo acceso programático)

6. Para cada usuario:
   - Hacer clic en **Next** (Permissions)
   - Omitir por ahora (se asignarán grupos después)
   - Review > Create user

7. **Crear Access Keys por separado** (para `admin-juan`, `dev-maria` y `app-service`):
   - Una vez creado el usuario, hacer clic en su nombre
   - Ir a la pestaña **Security credentials**
   - En **Access keys**, clic **Create access key**
   - Seleccionar caso de uso (p. ej. *CLI*) y confirmar
   - **IMPORTANTE**: Descargar el archivo CSV con la Access Key ID y Secret Access Key en ese momento; no podrá recuperarse después.

---

### Paso 2: Crear Grupos con Políticas

1. En IAM, navegar a **User groups** > **Create group**

2. Crear el grupo **Administrators**:
   - **Group name**: `Administrators`
   - En la sección **Attach policy**, buscar y seleccionar:
     - ✓ `AdministratorAccess` (AWS managed policy)
   - Create group

3. Crear el grupo **Developers**:
   - **Group name**: `Developers`
   - En la sección **Attach policy**, buscar y seleccionar:
     - ✓ `AmazonEC2FullAccess`
     - ✓ `AmazonS3FullAccess`
     - ✓ `CloudWatchFullAccess`
   - Create group

4. Crear el grupo **Analysts**:
   - **Group name**: `Analysts`
   - En la sección **Attach policy**, buscar y seleccionar:
     - ✓ `ReadOnlyAccess`
     - ✓ `AWSBillingReadOnlyAccess` (o `Billing` si aparece)
   - Create group

---

### Paso 3: Asignar Usuarios a Grupos

1. En IAM > **User groups**, seleccionar el grupo **Administrators**

2. Ir a **Add users to group**:
   - Seleccionar `admin-juan`
   - Add users

3. Ir al grupo **Developers**:
   - Añadir `dev-maria`

4. Ir al grupo **Analysts**:
   - Añadir `analyst-pedro`

5. Verificar las asignaciones en la pestaña **Users** de cada grupo.

---

### Paso 4: Crear Política Personalizada

1. En IAM, navegar a **Policies** > **Create policy**

2. Seleccionar la pestaña **JSON** y reemplazar el contenido con:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:ListBucket"
      ],
      "Resource": "arn:aws:s3:::*-bucket-proyecto/*"
    },
    {
      "Effect": "Deny",
      "Action": [
        "s3:DeleteObject",
        "s3:DeleteBucket"
      ],
      "Resource": "arn:aws:s3:::*-bucket-proyecto/*"
    }
  ]
}
```

3. Hacer clic en **Next: Tags** (opcional, añadir etiqueta Purpose=Proyecto)

4. **Next: Review**:
   - **Name**: `ProyectoBucketAccess`
   - **Description**: Política que permite lectura y escritura en buckets de proyecto, pero niega eliminación

5. Create policy

---

### Paso 5: Crear Rol para Servicio AWS (EC2)

1. En IAM, navegar a **Roles** > **Create role**

2. En **Select type of trusted entity**, seleccionar:
   - **AWS service**
   - **Common use cases**: EC2

3. Hacer clic en **Next: Permissions**

4. En la lista de políticas, buscar y seleccionar:
   - ✓ `AmazonS3ReadOnlyAccess`

5. Hacer clic en **Next: Tags** > **Next: Review**

6. Configurar:
   - **Role name**: `EC2S3ReadOnlyRole`
   - **Role description**: Rol para instancias EC2 con acceso de solo lectura a S3

7. Create role

8. Editar la **trust policy** del rol para permitir que EC2 asuma el rol:
   - Seleccionar el rol `EC2S3ReadOnlyRole`
   - Ir a **Trust relationships** > **Edit trust relationship**
   - Verificar que contiene:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

---

### Paso 6: Habilitar MFA para Usuario Administrador

1. En IAM > **Users**, seleccionar `admin-juan`

2. Ir a la pestaña **Security credentials**

3. En la sección **Assigned MFA device**, hacer clic en **Manage**

4. Seleccionar **Virtual MFA device** (Google Authenticator o Authy)

5. Hacer clic en **Continue** y mostrar el código QR

6. En la aplicación de autenticación:
   - Escanear el código QR, o
   - Introducir la clave secreta manualmente
   - Ingresar dos códigos MFA consecutivos de la aplicación

7. Assign MFA

---

### Paso 7: Crear Política que Requiera MFA para Acciones Sensibles

1. En IAM > **Policies** > **Create policy**

2. Seleccionar **JSON** y pegar:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Deny",
      "Action": "*",
      "Resource": "*",
      "Condition": {
        "Bool": {
          "aws:MultiFactorAuthPresent": false
        }
      }
    }
  ]
}
```

3. **Next: Tags** > **Next: Review**:
   - **Name**: `RequireMFAForAllActions`
   - **Description**: Niega todas las acciones si no hay MFA presente

4. Create policy

5. (Opcional) Attach esta política al grupo Administrators para requerir MFA en todas las acciones del grupo.

---

## Verificación

Al finalizar el lab, el estudiante debe poder verificar:

- [ ] **Verificar usuarios creados**: En IAM > Users, confirmar que existen `admin-juan`, `dev-maria`, `analyst-pedro` y `app-service`

- [ ] **Verificar grupos**: En IAM > User groups, confirmar que existen `Administrators`, `Developers` y `Analysts`

- [ ] **Verificar membresías**:
  - `admin-juan` pertenece a `Administrators`
  - `dev-maria` pertenece a `Developers`
  - `analyst-pedro` pertenece a `Analysts`

- [ ] **Verificar política personalizada**: En IAM > Policies, confirmar que existe `ProyectoBucketAccess` y que su JSON es correcto

- [ ] **Verificar rol EC2**: En IAM > Roles, confirmar que existe `EC2S3ReadOnlyRole` con política `AmazonS3ReadOnlyAccess`

- [ ] **Verificar MFA**: En las credenciales de `admin-juan`, confirmar que tiene un dispositivo MFA asignado

---

## Errores Comunes y Soluciones

| Error | Causa | Solución |
|-------|-------|----------|
| Access Denied al crear usuarios | Permisos insuficientes | Verificar que el usuario actual tiene permisos de AdministratorAccess |
| No aparecen políticas al buscar | Error de tipeo o mayúsculas | Usar exactamente el nombre de la política, verificar mayúsculas/minúsculas |
| MFA no se activa | Códigos desincronizados | Abrir la app de MFA y esperar a que cambie el código antes de ingresarlo |
| Trust policy incorrecta | JSON malformado | Usar el JSON exacto proporcionado, verificar comillas y corchetes |
| Policy no tiene efecto | Policy no attached | Confirmar que la política está attachada al usuario, grupo o rol correcto |

---

## Limpieza (Opcional)

Para evitar costos, eliminar los recursos creados:

1. Eliminar usuarios: IAM > Users > Delete user
2. Eliminar grupos: IAM > User groups > Delete group
3. Eliminar políticas: IAM > Policies > Delete policy
4. Eliminar roles: IAM > Roles > Delete role

---

## Referencias

- [IAM User Guide](https://docs.aws.amazon.com/iam/latest/userguide/)
- [IAM Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)
- [Using Multi-Factor Authentication](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_mfa.html)
