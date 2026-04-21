# Lab 3.2: Implementación de Cifrado S3 con KMS

## Objetivo

Configurar cifrado en buckets S3 utilizando SSE-KMS (Server-Side Encryption with AWS Key Management Service), crear una KMS Key (Customer Managed Key) personalizada, y verificar el acceso a objetos cifrados mediante auditorías en CloudTrail.

## Duración estimada

60 minutos

## Prerrequisitos

- Cuenta AWS con permisos de administrador o permisos específicos para S3 y KMS
- AWS CLI instalado y configurado con credenciales apropiadas
- Un archivo de prueba para subir al bucket (por ejemplo, `datos.txt`)

## Recursos

- Tiempo aproximado: 60 minutos
- Costos: AWS KMS tiene costo de $1/mes por KMS Key + cargos por uso de API

---

## Pasos

### Paso 1: Crear KMS Key (Customer Managed Key)

1. En la consola AWS, navegar a **KMS** > **Customer managed keys** > **Create key**

2. Configurar la clave:
   - **Key type**: Symmetric (por defecto)
   - **Key usage**: Encrypt and decrypt
   - **Advanced options**:
     - **Key material origin**: KMS
     - **Regionality**: Single-Region key

3. Hacer clic en **Next**

4. **Step 1 - Configure key**:
   - **Alias**: `mi-clave-cifrado`
   - **Description**: Clave de cifrado para labs de seguridad
   - **Tags** (opcional): `Purpose=Education`

5. **Step 2 - Define key administrative permissions**:
   - Seleccionar el usuario o rol actual como **Key administrator**
   - Opciones: `Allow key administrators to delete this key` (desactivar para este lab)

6. **Step 3 - Define key usage permissions**:
   - Seleccionar el usuario o rol actual en **This account**
   - Permitir uso de la clave

7. **Step 4 - Review and edit**:
   - Revisar configuración
   - Hacer clic en **Create key**

8. **IMPORTANTE**: Una vez creada, guardar el **ARN** de la clave (algo como `arn:aws:kms:us-east-1:123456789012:key/xxxx-xxxx-xxxx`)

---

### Paso 2: Crear Bucket S3

1. Navegar a **S3** > **Buckets** > **Create bucket**

2. Configurar el bucket:
   - **Bucket name**: `mi-bucket-cifrado-XXXX` (reemplazar XXXX con fecha, sin espacios ni mayúsculas)
   - **Region**: US East (N. Virginia) o la región preferida
   - **Copy settings from existing bucket**: Ninguna opción

3. Dejar las demás opciones por defecto

4. Create bucket

---

### Paso 3: Habilitar SSE-KMS como Cifrado por Defecto

1. En la lista de buckets, hacer clic en el bucket recién creado (`mi-bucket-cifrado-XXXX`)

2. Ir a la pestaña **Properties**

3. En la sección **Default encryption**, hacer clic en **Edit**

4. Configurar:
   - **Encryption type**: Choose **AWS Key Management Service key (SSE-KMS)**
   - **AWS KMS key**: Seleccionar **Choose from your existing keys**
   - **KMS master key**: Seleccionar `mi-clave-cifrado` (o el alias de la clave creada)

5. Save changes

---

### Paso 4: Verificar Configuración sin Cifrado Específico

1. Usando AWS CLI, crear un archivo de prueba:
```bash
echo "Datos confidenciales del lab 3.2" > datos.txt
```

2. Subir el archivo sin especificar cifrado:
```bash
aws s3 cp datos.txt s3://mi-bucket-cifrado-XXXX/
```

3. Verificar que el objeto fue cifrado:
```bash
aws s3api head-object --bucket mi-bucket-cifrado-XXXX --key datos.txt
```

4. En la salida, verificar que contiene:
   - `"ServerSideEncryption": "aws:kms"`
   - `"SSEKMSKeyId": "<ARN de la KMS Key>"`

---

### Paso 5: Crear Política de Bucket que Requiera Cifrado KMS

1. En el bucket S3, ir a la pestaña **Permissions**

2. En la sección **Bucket policy**, hacer clic en **Edit**

3. Añadir la siguiente política:

```json
{
  "Version": "2012-10-17",
  "Id": "RequireKMSEncryption",
  "Statement": [
    {
      "Sid": "DenyUnEncryptedObjectUploads",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:PutObject",
      "Resource": "arn:aws:s3:::mi-bucket-cifrado-XXXX/*",
      "Condition": {
        "StringNotEquals": {
          "s3:x-amz-server-side-encryption": "aws:kms"
        }
      }
    },
    {
      "Sid": "DenyActionsWithoutKMSKey",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:PutObject",
      "Resource": "arn:aws:s3:::mi-bucket-cifrado-XXXX/*",
      "Condition": {
        "Null": {
          "s3:x-amz-server-side-encryption-aws-kms-key-id": true
        }
      }
    }
  ]
}
```

**NOTA**: Reemplazar `mi-bucket-cifrado-XXXX` con el nombre real del bucket.

4. Save changes

---

### Paso 6: Verificar que la Política Bloquea Uploads sin Cifrado KMS

1. Intentar subir un archivo con SSE-S3 (debe fallar):
```bash
aws s3 cp datos.txt s3://mi-bucket-cifrado-XXXX/archivo-sse-s3.txt --sse AES256
```

2. Verificar que la respuesta es **Access Denied**

3. Subir un archivo con SSE-KMS especificando la clave (debe funcionar):
```bash
aws s3 cp datos.txt s3://mi-bucket-cifrado-XXXX/archivo-kms.txt --sse aws:kms --sse-kms-key-id <ARN-de-la-KMS-Key>
```

**NOTA**: Es obligatorio indicar `--sse-kms-key-id` porque la bucket policy deniega uploads que no incluyan el header del key ID.

4. Verificar que la subida fue exitosa

---

### Paso 7: Verificar Uso de Claves en CloudTrail

1. En la consola AWS, navegar a **CloudTrail** > **Event history**

2. Filtrar por:
   - **Lookup attributes**: Event source = `kms.amazonaws.com`
   - **Time range**: Last 15 minutes

3. Buscar eventos:
   - `GenerateDataKey`: Cuando se sube un objeto (S3 genera la clave de datos)
   - `Decrypt`: Cuando se descarga un objeto (S3 descifra la clave de datos)

   **NOTA**: S3 SSE-KMS **no genera** el evento `Encrypt`. Solo aparecería si se invocara KMS directamente (`aws kms encrypt`).

4. Hacer clic en un evento para ver los detalles:
   - Verificar `keyId` coincide con la KMS Key creada
   - Verificar `encryptionContext` si está presente

5. (Opcional) Descargar el objeto para generar un evento de `Decrypt`:
```bash
aws s3 cp s3://mi-bucket-cifrado-XXXX/archivo-kms.txt ./descargado.txt
```

6. Verificar en CloudTrail que aparece el evento `Decrypt`

---

## Verificación

Al finalizar el lab, el estudiante debe poder verificar:

- [ ] **KMS Key creada**: En KMS, confirmar que existe `mi-clave-cifrado` con estado **Enabled**

- [ ] **Bucket con cifrado por defecto**: En S3, Properties del bucket muestra SSE-KMS habilitado

- [ ] **Objeto cifrado**: Al hacer `head-object`, el objeto muestra `ServerSideEncryption: aws:kms`

- [ ] **Policy funcionando**: Un intento de upload con SSE-S3 es denegado con Access Denied

- [ ] **Upload exitoso con KMS**: Un upload con `--sse aws:kms` es exitoso

- [ ] **CloudTrail muestra eventos KMS**: Los eventos de cifrado/descifrado aparecen en el historial

---

## Errores Comunes y Soluciones

| Error | Causa | Solución |
|-------|-------|----------|
| Access Denied al crear KMS Key | Permisos insuficientes | Verificar que el usuario tiene permisos `kms:CreateKey` y `kms:CreateAlias` |
| Upload falla aunque tiene cifrado | Policy mal configurada | Verificar que el nombre del bucket en la policy coincide exactamente |
| `head-object` no muestra cifrado | Bucket no tiene cifrado por defecto | Habilitar default encryption en Properties del bucket |
| CloudTrail no muestra eventos | Trail no configurado | Verificar que CloudTrail está capturando eventos de KMS |
| Null condition no funciona | Condition mal formulada | Usar `StringNotEquals` con `"s3:x-amz-server-side-encryption": "aws:kms"` |

---

## Limpieza (Opcional)

Para evitar costos continuos:

1. **Eliminar objetos del bucket**:
```bash
aws s3 rm s3://mi-bucket-cifrado-XXXX/ --recursive
```

2. **Eliminar el bucket**:
```bash
aws s3 rb s3://mi-bucket-cifrado-XXXX --force
```

3. **Deshabilitar y eliminar la KMS Key** (requiere esperar 7-30 días si está programada para eliminación):
   - En KMS, seleccionar la clave > **Key actions** > **Schedule key deletion**

---

## Referencias

- [KMS Developer Guide](https://docs.aws.amazon.com/kms/latest/developerguide/)
- [S3 Server-Side Encryption](https://docs.aws.amazon.com/AmazonS3/latest/userguide/serv-side-encryption.html)
- [Using SSE-KMS with S3](https://docs.aws.amazon.com/AmazonS3/latest/userguide/UsingKMSEncryption.html)
- [CloudTrail with KMS](https://docs.aws.amazon.com/kms/latest/developerguide/services-cloudtrail.html)
