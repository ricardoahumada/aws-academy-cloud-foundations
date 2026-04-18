# Lab 6.1: Desplegar API Serverless con Lambda + API Gateway

## Objetivo

Crear una API REST serverless completa usando Lambda como backend de procesamiento y API Gateway como punto de entrada. Al finalizar, tendrás una API funcional con endpoints para listar usuarios y obtener un usuario específico por ID.

## Duración estimada

60 minutos

## Prerrequisitos

- Cuenta AWS activa con acceso a los servicios Lambda y API Gateway
- AWS CLI configurado con credenciales válidas (`aws configure`)
- Editor de código instalado (VS Code recomendado)
- Conocimientos básicos de Python y APIs REST
- Permisos IAM suficientes para crear funciones Lambda, roles y APIs

## Recursos creados

| Recurso | Nombre | Tipo |
|---------|--------|------|
| Función Lambda | `get-users-function` | AWS Lambda |
| REST API | `users-api` | Amazon API Gateway |
| Role IAM | Auto-generado por Lambda | IAM |

---

## Pasos

### Paso 1: Crear la Función Lambda

1.1. Abre la consola de AWS en https://console.aws.amazon.com

1.2. Navega a **Lambda** > **Functions** > **Create function**

1.3. En la página de creación, configura:
   - **Function name**: `get-users-function`
   - **Runtime**: `Python 3.11`
   - **Architecture**: `x86_64`
   - **Permissions**: Selecciona **Create a new role with basic Lambda permissions**
   - **Advanced settings**: Dejar valores por defecto

1.4. Haz clic en **Create function**

1.5. En el editor de código de la función, reemplaza todo el código existente con lo siguiente:

```python
import json

# Sample data (replace with DynamoDB in production)
USERS = [
    {'id': '1', 'name': 'Juan Pérez', 'email': 'juan@example.com'},
    {'id': '2', 'name': 'María García', 'email': 'maria@example.com'},
    {'id': '3', 'name': 'Carlos López', 'email': 'carlos@example.com'}
]

def lambda_handler(event, context):
    # Get HTTP method
    http_method = event.get('httpMethod', 'GET')
    
    # Get path
    path = event.get('path', '/')
    
    if http_method == 'GET' and path == '/users':
        return {
            'statusCode': 200,
            'body': json.dumps({'users': USERS, 'count': len(USERS)}),
            'headers': {'Content-Type': 'application/json'}
        }
    elif http_method == 'GET' and path.startswith('/users/'):
        user_id = path.split('/')[-1]
        user = next((u for u in USERS if u['id'] == user_id), None)
        if user:
            return {
                'statusCode': 200,
                'body': json.dumps(user),
                'headers': {'Content-Type': 'application/json'}
            }
        return {
            'statusCode': 404,
            'body': json.dumps({'error': 'User not found'}),
            'headers': {'Content-Type': 'application/json'}
        }
    else:
        return {
            'statusCode': 400,
            'body': json.dumps({'error': 'Invalid request'}),
            'headers': {'Content-Type': 'application/json'}
        }
```

1.6. Haz clic en **Deploy** para guardar y desplegar la función

1.7. Verifica que la función aparece con estado `Ready` y el indicador de despliegue exitoso

---

### Paso 2: Crear la REST API en API Gateway

2.1. Navega a **API Gateway** en la consola de AWS

2.2. En la sección **REST API**, haz clic en **Build**

2.3. En el diálogo de configuración:
   - Selecciona **REST**
   - **Protocol**: REST
   - **Create new API**: New API
   - **API name**: `users-api`
   - **Endpoint Type**: Regional
   - **Description** (opcional): `API para gestionar usuarios`

2.4. Haz clic en **Create API**

---

### Paso 3: Crear el Resource `/users`

3.1. Con la API creada, en el panel izquierdo busca **Resources**

3.2. Asegúrate de que el path `/` está seleccionado

3.3. Haz clic en **Actions** > **Create Resource**

3.4. En el panel de configuración del recurso:
   - **Resource Name**: `users`
   - **Resource Path**: `/users`
   - **Enable API Gateway CORS**: Yes (recomendado para evitar problemas de CORS)

3.5. Haz clic en **Create Resource**

---

### Paso 4: Crear el Method GET en `/users`

4.1. Selecciona el recurso `/users` recién creado

4.2. Haz clic en **Actions** > **Create Method**

4.3. En el dropdown, selecciona **GET** y haz clic en el checkmark

4.4. En la configuración del método:
   - **Integration type**: Lambda Function
   - **Use Lambda Proxy integration**: Yes
   - **Lambda region**: Selecciona tu región (ej: us-east-1)
   - **Lambda function**: `get-users-function`

4.5. Haz clic en **Save**

4.6. Si aparece un diálogo de confirmación de permisos, haz clic en **OK**

---

### Paso 5: Crear el Resource `/users/{id}`

5.1. Selecciona el recurso `/users` en el panel izquierdo

5.2. Haz clic en **Actions** > **Create Resource**

5.3. Configura:
   - **Resource Name**: `user-id`
   - **Resource Path**: `/users/{id}`
   - **Enable API Gateway CORS**: Yes

5.4. Haz clic en **Create Resource**

---

### Paso 6: Crear el Method GET en `/users/{id}`

6.1. Selecciona el recurso `/users/{id}`

6.2. Haz clic en **Actions** > **Create Method**

6.3. Selecciona **GET** y haz clic en el checkmark

6.4. Configura:
   - **Integration type**: Lambda Function
   - **Use Lambda Proxy integration**: Yes
   - **Lambda region**: Tu región
   - **Lambda function**: `get-users-function`

6.5. Haz clic en **Save**

---

### Paso 7: Desplegar la API

7.1. Con cualquier recurso seleccionado, haz clic en **Actions** > **Deploy API**

7.2. En el diálogo de despliegue:
   - **Stage**: [New Stage]
   - **Stage name**: `prod`
   - **Stage description**: Producción
   - **Deployment description**: `Versión inicial`

7.3. Haz clic en **Deploy**

7.4. En la página del stage `prod`, copia la **Invoke URL** que aparece en la parte superior. Debería tener el formato:
   ```
   https://<api-id>.execute-api.<region>.amazonaws.com/prod
   ```

---

### Paso 8: Probar la API

8.1. Abre una terminal o command prompt

8.2. Prueba el endpoint para obtener todos los usuarios:

```bash
curl https://<api-id>.execute-api.<region>.amazonaws.com/prod/users
```

8.3. Verifica que la respuesta sea similar a:
```json
{"users": [{"id": "1", "name": "Juan Pérez", "email": "juan@example.com"}, {"id": "2", "name": "María García", "email": "maria@example.com"}, {"id": "3", "name": "Carlos López", "email": "carlos@example.com"}], "count": 3}
```

8.4. Prueba el endpoint para obtener un usuario específico:

```bash
curl https://<api-id>.execute-api.<region>.amazonaws.com/prod/users/1
```

8.5. Verifica que la respuesta sea:
```json
{"id": "1", "name": "Juan Pérez", "email": "juan@example.com"}
```

8.6. Prueba solicitando un usuario que no existe:

```bash
curl https://<api-id>.execute-api.<region>.amazonaws.com/prod/users/999
```

8.7. Verifica que la respuesta tenga status 404:
```json
{"error": "User not found"}
```

---

### Paso 9: Configurar Throttling (Opcional)

9.1. En API Gateway, selecciona tu API `users-api`

9.2. En el panel izquierdo, selecciona **Stages** > `prod`

9.3. En la pestaña **Stage editor**, desplázate hasta la sección **Default Method Throttling**:
   - **Rate**: `100` requests/second
   - **Burst**: `50`

9.4. Haz clic en **Save Changes**

> **Nota:** Para aplicar throttling a métodos individuales, usa la pestaña **Default Method Throttling** dentro de **Stages** y expande el recurso correspondiente.

---

## Verificación

Al finalizar el lab, verifica que puedes realizar las siguientes acciones:

- [ ] La función Lambda `get-users-function` está creada y tiene estado `Active`
- [ ] La REST API `users-api` está creada en API Gateway
- [ ] El recurso `/users` existe con método GET configurado
- [ ] El recurso `/users/{id}` existe con método GET configurado
- [ ] La API está desplegada en el stage `prod`
- [ ] El comando `curl` a `/users` devuelve la lista de usuarios
- [ ] El comando `curl` a `/users/1` devuelve los datos del usuario con ID 1
- [ ] El comando `curl` a `/users/999` devuelve error 404 con mensaje appropriate

---

## Errores Comunes y Soluciones

| Error | Causa probable | Solución |
|-------|---------------|----------|
| `Missing Authentication Token` | El método no está configurado o la URL es incorrecta | Verificar que el método GET existe en el recurso y que la URL está completa |
| `Internal Server Error` | Error en la función Lambda | Revisar los logs de CloudWatch para la función Lambda |
| `403 Forbidden` | Permisos insuficientes | Verificar que el rol de ejecución de Lambda tiene permisos adecuados |
| CORS errors en el navegador | CORS no habilitado | Habilitar CORS en los recursos de API Gateway |
| La API no responde | API no desplegada | Asegurarse de hacer Deploy después de crear los recursos |
| `Lambda does not have access` | Permisos de API Gateway | Aceptar los permisos al crear la integración Lambda |

---

## Limpieza de Recursos

Para eliminar los recursos creados y evitar costos adicionales:

1. **Eliminar la API Gateway**:
   - API Gateway > APIs > `users-api` > Actions > Delete

2. **Eliminar la función Lambda**:
   - Lambda > Functions > `get-users-function` > Actions > Delete

El rol IAM asociado se eliminará automáticamente al borrar la función Lambda.

---

## Extensiones Opcionales

Si completaste el lab y deseas practicar más:

1. **Agregar método POST**: Crear un endpoint para crear nuevos usuarios
2. **Agregar método DELETE**: Crear un endpoint para eliminar usuarios
3. **Integrar con DynamoDB**: Reemplazar el array estático USERS por una tabla DynamoDB
4. **Agregar autenticación**: Implementar API keys o Cognito para proteger los endpoints
5. **Configurar caching**: Habilitar cache en API Gateway para mejorar rendimiento
