# Lab 3.4: Roles Avanzados y Políticas Complejas

## Objetivo

Practicar con características avanzadas de IAM: permission boundaries para limitar permisos incluso con AdministratorAccess, cross-account access usando roles, resource-based policies en buckets S3, y conditions complejas en políticas (MFA, region, IP).

## Duración estimada

45 minutos

## Prerrequisitos

- Dos cuentas AWS (o simular con una sola cuenta usando diferente IAM user)
- Permisos de administrador en ambas cuentas
- AWS CLI configurado con credenciales de administrador
- jq instalado (para parsear JSON en scripts de bash)

## Recursos

- Tiempo aproximado: 45 minutos
- Costos: Este lab usa solo servicios gratuitos (IAM, S3 en tier gratuito)

---

## Pasos

### Paso 1: Crear Permission Boundary Personalizado

1. En la consola AWS, navegar a **IAM** > **Policies** > **Create policy**

2. Seleccionar la pestaña **JSON** y pegar:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:ListBucket",
        "ec2:DescribeInstances",
        "ec2:DescribeSecurityGroups",
        "cloudwatch:ListMetrics",
        "cloudwatch:GetMetricData"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Deny",
      "Action": [
        "s3:DeleteObject",
        "s3:DeleteBucket"
      ],
      "Resource": "*"
    }
  ]
}
```

3. Hacer clic en **Next: Tags** (opcional)

4. **Next: Review**:
   - **Policy name**: `DeveloperBoundary`
   - **Description**: Límite de permisos para desarrolladores - solo lectura y escritura limitada de S3, sin eliminación

5. Create policy

---

### Paso 2: Crear Usuario con Permission Boundary

1. En IAM > **Users** > **Add user**

2. Configurar:
   - **User name**: `developer-limitado`
   - **Access type**: Programmatic access only
   - **Next: Permissions**

3. En la página **Set permissions**:
   - Seleccionar **Attach existing policies directly**
   - Buscar y seleccionar `AdministratorAccess`
   - **IMPORTANTE**: En la sección **Permission boundaries**, seleccionar **Use a permissions boundary**
   - Elegir la política `DeveloperBoundary`

4. Review > Create user

5. Descargar las credenciales (CSV) y guardar el **Access Key ID** y **Secret Access Key**

---

### Paso 3: Verificar Límites del Permission Boundary

1. Configurar variables de entorno con las credenciales del nuevo usuario:
```bash
export AWS_ACCESS_KEY_ID="AKIAIOSFODNN7EXAMPLE"
export AWS_SECRET_ACCESS_KEY="wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
export AWS_DEFAULT_REGION="us-east-1"
```

2. Verificar identidad del usuario:
```bash
aws sts get-caller-identity
```

3. Probar acciones que DEBEN funcionar:
```bash
# Listar buckets (Allow en boundary)
aws s3 ls

# Copiar archivo a S3 (Allow en boundary)
echo "test" > test.txt
aws s3 cp test.txt s3://mi-bucket-test/archivo.txt
```

4. Probar acciones que DEBEN FALLAR por el boundary:

```bash
# Eliminar objeto (Deny en boundary) - DEBE FALLAR
aws s3 rm s3://mi-bucket-test/archivo.txt
# Resultado esperado: Access Denied

# Crear usuario (no está en boundary) - DEBE FALLAR
aws iam create-user --user-name nuevo-usuario
# Resultado esperado: Access Denied
```

5. Verificar que el boundary limita los permisos incluso con AdministratorAccess

---

### Paso 4: Crear Rol Cross-Account (Cuenta B - Recursos)

**Este paso se realiza en la cuenta que tendrá los recursos (Cuenta B)**

1. En la consola de la **Cuenta B**, ir a **IAM** > **Roles** > **Create role**

2. En **Select type of trusted entity**:
   - Seleccionar **Another AWS account**
   - **Account ID**: Escribir el ID de la **Cuenta A** (la cuenta desde donde se accederá)

3. Opcional: Marcar **Require external ID** (anotar la external ID para usar después)

4. Hacer clic en **Next: Permissions**

5. Seleccionar la política:
   - ✓ `AmazonS3ReadOnlyAccess`

6. **Next: Tags** > **Next: Review**:
   - **Role name**: `CrossAccountS3ReadRole`
   - **Role description**: Rol para acceso cross-account a S3 en cuenta B

7. Create role

8. Copiar el **ARN del rol** (algo como `arn:aws:iam::999999999999:role/CrossAccountS3ReadRole`)

---

### Paso 5: Assumir Rol Cross-Account desde Cuenta A

**Este paso se realiza en la Cuenta A**

1. Crear un bucket en la Cuenta B (si no existe):
```bash
# En Cuenta B
aws s3 mb s3://bucket-cross-account-test
```

2. Desde Cuenta A, asumir el rol de Cuenta B:

**Linux/Mac (bash):**
```bash
# Variables
ROLE_ARN="arn:aws:iam::999999999999:role/CrossAccountS3ReadRole"
SESSION_NAME="test-cross-account-session"

# Assumir rol y extraer credenciales usando --query (sin jq)
TEMP_CREDS=$(aws sts assume-role \
  --role-arn $ROLE_ARN \
  --role-session-name $SESSION_NAME \
  --output json)

ACCESS_KEY=$(aws sts assume-role --role-arn $ROLE_ARN --role-session-name $SESSION_NAME --query 'Credentials.AccessKeyId' --output text)
SECRET_KEY=$(aws sts assume-role --role-arn $ROLE_ARN --role-session-name $SESSION_NAME --query 'Credentials.SecretAccessKey' --output text)
TOKEN=$(aws sts assume-role --role-arn $ROLE_ARN --role-session-name $SESSION_NAME --query 'Credentials.SessionToken' --output text)
```

**Windows (PowerShell):**
```powershell
$ROLE_ARN = "arn:aws:iam::999999999999:role/CrossAccountS3ReadRole"
$SESSION_NAME = "test-cross-account-session"

$TEMP_CREDS = aws sts assume-role `
  --role-arn $ROLE_ARN `
  --role-session-name $SESSION_NAME | ConvertFrom-Json

$ACCESS_KEY  = $TEMP_CREDS.Credentials.AccessKeyId
$SECRET_KEY  = $TEMP_CREDS.Credentials.SecretAccessKey
$TOKEN       = $TEMP_CREDS.Credentials.SessionToken
```

3. Configurar las credenciales temporales:

**Linux/Mac:**
```bash
export AWS_ACCESS_KEY_ID=$ACCESS_KEY
export AWS_SECRET_ACCESS_KEY=$SECRET_KEY
export AWS_SESSION_TOKEN=$TOKEN
```

**Windows (PowerShell):**
```powershell
$env:AWS_ACCESS_KEY_ID     = $ACCESS_KEY
$env:AWS_SECRET_ACCESS_KEY = $SECRET_KEY
$env:AWS_SESSION_TOKEN     = $TOKEN
```

4. Verificar acceso cross-account:
```bash
# Verificar identidad (debe mostrar el ARN del rol)
aws sts get-caller-identity
# Resultado: Role: arn:aws:iam::999999999999:role/CrossAccountS3ReadRole

# Listar buckets (debe funcionar por permisos del rol)
aws s3 ls
```

5. Verificar que el acceso es de solo lectura:
```bash
# Leer objeto (debe funcionar)
aws s3 ls s3://bucket-cross-account-test/

# Intentar escribir (debe fallar - solo ReadOnlyAccess)
aws s3 cp test.txt s3://bucket-cross-account-test/
# Resultado: Access Denied
```

---

### Paso 6: Crear Resource-Based Policy en Bucket S3

**Este paso se realiza en la Cuenta B**

1. En la Cuenta B, navegar a **S3** > Seleccionar el bucket `bucket-cross-account-test`

2. Ir a la pestaña **Permissions**

3. En **Bucket policy**, hacer clic en **Edit**

4. Añadir la siguiente política:

```json
{
  "Version": "2012-10-17",
  "Id": "CrossAccountAccessPolicy",
  "Statement": [
    {
      "Sid": "AllowCrossAccountList",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::111111111111:root"
      },
      "Action": "s3:ListBucket",
      "Resource": "arn:aws:s3:::bucket-cross-account-test"
    },
    {
      "Sid": "AllowCrossAccountGetObject",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::111111111111:root"
      },
      "Action": [
        "s3:GetObject",
        "s3:PutObject"
      ],
      "Resource": "arn:aws:s3:::bucket-cross-account-test/*"
    },
    {
      "Sid": "DenyDelete",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:DeleteObject",
      "Resource": "arn:aws:s3:::bucket-cross-account-test/*"
    }
  ]
}
```

**IMPORTANTE**: Reemplazar `111111111111` con el Account ID real de la Cuenta A.

5. Save changes

---

### Paso 7: Verificar Condition Keys en Políticas

1. Crear una política que requiera MFA para acciones sensibles:
   - IAM > Policies > Create policy > JSON

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "iam:CreateUser",
        "iam:DeleteUser",
        "iam:AttachUserPolicy",
        "iam:DetachUserPolicy"
      ],
      "Resource": "*",
      "Condition": {
        "Bool": {
          "aws:MultiFactorAuthPresent": true
        }
      }
    }
  ]
}
```

2. Name: `IAMWithMFARequired`

3. Create policy

4. Crear un usuario de prueba sin MFA:
```bash
# Con credenciales de admin
aws iam create-user --user-name test-mfa-user
aws iam attach-user-policy --user-name test-mfa-user --policy-arn arn:aws:iam::111111111111:policy/IAMWithMFARequired
```

5. Intentar crear otro usuario con el usuario de prueba (debe fallar):
```bash
# Configurar credenciales del usuario sin MFA
export AWS_ACCESS_KEY_ID="<access-key-test-mfa-user>"
export AWS_SECRET_ACCESS_KEY="<secret-key-test-mfa-user>"

# Intentar crear usuario (debe fallar)
aws iam create-user --user-name nuevo-usuario
# Resultado: Access Denied (MFA required)
```

6. Habilitar MFA para el usuario y repetir la prueba (debe funcionar)

---

## Verificación

Al finalizar el lab, el estudiante debe poder verificar:

- [ ] **Permission boundary creado**: En IAM > Policies, existe `DeveloperBoundary`

- [ ] **Usuario con boundary**: El usuario `developer-limitado` tiene `AdministratorAccess` y `DeveloperBoundary` como permission boundary

- [ ] **Boundary funciona**:即使 con AdministratorAccess, el usuario no puede eliminar objetos S3 ni crear usuarios IAM

- [ ] **Rol cross-account creado**: En Cuenta B, existe `CrossAccountS3ReadRole` con trust policy hacia Cuenta A

- [ ] **Assume role exitoso**: Desde Cuenta A, se pueden obtener credenciales temporales del rol de Cuenta B

- [ ] **Acceso cross-account funciona**: Usando credenciales temporales, se puede listar bucket en Cuenta B

- [ ] **Resource-based policy aplicada**: El bucket tiene política que permite acceso desde Cuenta A

- [ ] **Condición MFA funciona**: Un usuario con política `IAMWithMFARequired` no puede ejecutar acciones sin MFA

---

## Errores Comunes y Soluciones

| Error | Causa | Solución |
|-------|-------|----------|
| Access Denied al asumir rol | Trust policy incorrecta | Verificar que la cuenta en el Principal coincide exactamente con Cuenta A |
| External ID mismatch | External ID no coincide | Verificar que se usa la misma external ID configurada en el rol |
| Condition MFA no funciona | El usuario no tiene MFA | Verificar que el dispositivo MFA está asociado al usuario en IAM |
| Bucket policy malformada | JSON con errores de sintaxis | Usar validator de JSON, verificar comas y corchetes |
| Credenciales temporales expiradas | Duración por defecto (1h) | Usar `--duration-in-seconds` mayor o re-assumir el rol |
| Resource policy no permite acceso | Principal incorrecto | Verificar que el ARN del principal coincide exactamente con Cuenta A |

---

## Limpieza (Opcional)

1. **Eliminar usuario de prueba**:
```bash
aws iam delete-user --user-name developer-limitado
aws iam delete-user --user-name test-mfa-user
```

2. **Eliminar políticas**:
```bash
aws iam delete-policy --policy-arn arn:aws:iam::111111111111:policy/DeveloperBoundary
aws iam delete-policy --policy-arn arn:aws:iam::111111111111:policy/IAMWithMFARequired
```

3. **Eliminar rol cross-account** (en Cuenta B):
```bash
aws iam delete-role --role-name CrossAccountS3ReadRole
```

4. **Eliminar bucket**:
```bash
aws s3 rb s3://bucket-cross-account-test --force
```

---

## Referencias

- [IAM Permission Boundaries](https://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies_boundaries.html)
- [IAM Roles Terms and Concepts](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_terms-and-concepts.html)
- [Using IAM Roles with AWS STS](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_temp_use-resources.html)
- [S3 Bucket Policy Examples](https://docs.aws.amazon.com/AmazonS3/latest/userguide/example-bucket-policies.html)
- [IAM Policy Condition Keys](https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_condition-keys.html)
