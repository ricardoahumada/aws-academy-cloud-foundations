# Lab 7.2: Pipeline CI/CD para Imágenes con ECR y ECS (OPCIONAL)

## Objetivo

Crear un pipeline de CI/CD completo usando AWS CodePipeline y CodeBuild para construir y desplegar automáticamente imágenes de contenedor a Amazon ECS.

---

## Duración Estimada

**45 minutos**

---

## Prerrequisitos

- Repositorio ECR `my-webapp` creado en el Lab 7.1
- Bucket S3 para almacenar artifacts (creado o existente)
- Application Load Balancer y Target Group configurados
- Service ECS `my-webapp-service` en el cluster `my-cluster`
- Cuenta de GitHub con repositorio `webapp-repo` (CodeCommit descontinuado julio 2024)
- IAM roles básicos para CodeBuild y CodePipeline

---

## Recursos Necesarios

- Repositorio ECR con imagen inicial
- Bucket S3: `my-artifacts-bucket-<account-id>`
- Cluster ECS con service existente
- Repositorio en GitHub y CodeStar Connection configurada

---

## Pasos

### Paso 1: Preparar el Entorno Local

Antes de crear el pipeline, necesitas un repositorio de código fuente y el archivo buildspec.yml.

1.1. Crea un directorio para el proyecto:
   ```bash
   mkdir -p webapp-cicd
   cd webapp-cicd
   ```

1.2. Copia o clona tu aplicación web en este directorio.

> **📁 Archivos de Referencia**: Este lab incluye archivos de ejemplo que puedes usar como plantilla:
> - `lab-2/docker/Dockerfile` - Dockerfile multi-stage para Node.js
> - `lab-2/docker/task-def.json` - Definición de contenedor para ECS  
> - `lab-2/pipeline/buildspec.yml` - BuildSpec completo con deployment a ECS
>
> Puedes copiar estos archivos a tu repositorio o usarlos como referencia para crear los tuyos.

1.3. Crea el archivo `buildspec.yml` en la raíz del proyecto:
   ```yaml
   version: 0.2

   phases:
     pre_build:
       commands:
         - echo Logging in to Amazon ECR...
         - AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
         - AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION:-us-east-1}
         - aws ecr get-login-password --region $AWS_DEFAULT_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com
         - REPOSITORY_URI=$AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/my-webapp
         - IMAGE_TAG=${CODEBUILD_BUILD_NUMBER:-latest}
     build:
       commands:
         - echo Build started on `date`
         - echo Building the Docker image...
         - docker build -t $REPOSITORY_URI:latest .
         - docker tag $REPOSITORY_URI:latest $REPOSITORY_URI:$IMAGE_TAG
     post_build:
       commands:
         - echo Pushing the Docker image...
         - docker push $REPOSITORY_URI:latest
         - docker push $REPOSITORY_URI:$IMAGE_TAG
         - echo Writing image definitions...
         - printf '[{"name":"webapp","imageUri":"%s"}]' $REPOSITORY_URI:$IMAGE_TAG > imagedefinitions.json
         - echo Build completed on `date`

   artifacts:
     files:
       - imagedefinitions.json
   ```

   > **Nota**: Este buildspec simplificado permite que CodePipeline maneje el deployment automáticamente. Para un buildspec más completo que incluye actualización de task definition, consulta `lab-2/pipeline/buildspec.yml`.

1.4. Crea o copia el archivo `Dockerfile` de tu aplicación en la raíz del proyecto.

   > **Tip**: Puedes copiar el Dockerfile de ejemplo: `cp lab-2/docker/Dockerfile ./Dockerfile`

1.5. Verifica la estructura de tu repositorio:
   ```bash
   # La estructura debe verse así:
   webapp-cicd/
   ├── Dockerfile
   ├── buildspec.yml
   ├── package.json
   ├── src/
   └── public/
   ```

1.6. Inicializa git y configura:
   ```bash
   git init
   git config --global user.name "Tu Nombre"
   git config --global user.email "tu@email.com"
   ```

1.7. Haz el primer commit:
   ```bash
   git add .
   git commit -m "Initial commit with Dockerfile and buildspec"
   ```

---

### Paso 2: Crear Repositorio en GitHub y Conectar con CodeStar Connections

> **Nota:** AWS CodeCommit fue descontinuado para nuevos clientes en julio de 2024. Este lab usa GitHub integrado mediante **CodeStar Connections** (Developer Tools Connections).

2.1. Crea un repositorio en [github.com](https://github.com):
   - **Repository name**: `webapp-repo`
   - **Visibility**: Public o Private
   - Haz clic en **Create repository**

2.2. Conecta tu repositorio local a GitHub:
   ```bash
   git remote add origin https://github.com/<tu-usuario>/webapp-repo.git
   git branch -M main
   git push -u origin main
   ```

2.3. Crea una **CodeStar Connection** para GitHub:
   - Navega a **Developer Tools** > **Settings** > **Connections** en la consola de AWS
   - Clic en **Create connection**
   - Selecciona **GitHub** como provider
   - **Connection name**: `github-connection`
   - Clic en **Connect to GitHub** y autoriza el acceso a tu cuenta
   - Clic en **Connect**

2.4. Verifica que la conexión quede en estado **Available**:
   ```bash
   aws codestar-connections list-connections --provider-type GitHub
   ```

> **Anota el ARN de la conexión** — lo necesitarás al configurar CodeBuild y CodePipeline.

---

### Paso 3: Crear Bucket S3 para Artifacts

3.1. Navega a **S3** en la consola de AWS.

3.2. Haz clic en **"Create bucket"**.

3.3. Configura:
   - **Bucket name**: `my-artifacts-bucket-<account-id>` (debe ser único globalmente)
   - **Region**: `us-east-1`
   - **Block public access**: Activado (por seguridad)

3.4. Haz clic en **"Create bucket"**.

---

### Paso 4: Crear CodeBuild Project

4.1. Navega a **CodeBuild** en la consola de AWS.

4.2. Haz clic en **"Create project"**.

4.3. En **"Project configuration"**:
   - **Project name**: `webapp-build`

4.4. En **"Source"**:
   - **Source provider**: `GitHub (CodeStar Connections)`
   - **Connection**: seleccionar `github-connection`
   - **Repository**: `<tu-usuario>/webapp-repo`
   - **Branch**: `main`

4.5. En **"Environment"**:
   - **Environment image**: `Managed`
   - **Operating system**: `Amazon Linux 2`
   - **Runtime(s)**: `Standard`
   - **Image**: `aws/codebuild/amazonlinux2-x86_64-standard:5.0`
   - **Environment type**: `Linux`
   - **Privileged**: **Activar** (necesario para Docker)

4.6. En **"Build specifications"**:
   - **Buildspec name**: `buildspec.yml` (o deja el valor por defecto)

4.7. En **"Artifacts"**:
   - **Type**: `Amazon S3`
   - **Bucket name**: `my-artifacts-bucket-<account-id>`
   - **Path**: `build-output`
   - **Name**: `build-output.zip`
   - **Encryption**: Disabled

4.8. En **"Service role"**: Selecciona **"New service role"**.

4.9. Haz clic en **"Create build project"**.

---

### Paso 5: Configurar Permisos IAM para CodeBuild

CodeBuild necesita permisos para acceder a ECR y ECS.

5.1. Navega a **IAM** > **Roles**.

5.2. Encuentra el rol creado para CodeBuild (busca `codebuild-webapp-build-service-role`).

5.3. Adjunta las siguientes políticas:

   **AmazonECRFullAccess** (o crea una política más restrictiva):
   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Effect": "Allow",
         "Action": [
           "ecr:GetAuthorizationToken",
           "ecr:BatchCheckLayerAvailability",
           "ecr:GetDownloadUrlForLayer",
           "ecr:GetRepositoryPolicy",
           "ecr:DescribeRepositories",
           "ecr:ListImages",
           "ecr:DescribeImages",
           "ecr:BatchGetImage",
           "ecr:InitiateLayerUpload",
           "ecr:UploadLayerPart",
           "ecr:CompleteLayerUpload",
           "ecr:PutImage"
         ],
         "Resource": "*"
       }
     ]
   }
   ```

5.4. Asegúrate de que el rol tiene acceso a ECS:
   ```bash
   aws ecs describe-task-definition --task-definition my-webapp-task
   ```

---

### Paso 6: Crear CodePipeline

6.1. Navega a **CodePipeline** en la consola de AWS.

6.2. Haz clic en **"Create pipeline"**.

6.3. En **"Pipeline settings"**:
   - **Pipeline name**: `webapp-cicd`
   - **Service role**: **New service role**
   - **Artifact store**: `Default location`

6.4. En **"Source stage"**:
   - **Source provider**: `GitHub (Version 2)`
   - **Connection**: seleccionar `github-connection`
   - **Repository name**: `<tu-usuario>/webapp-repo`
   - **Branch name**: `main`
   - **Output artifact format**: `CodePipeline default`

6.5. En **"Build stage"**:
   - **Build provider**: `AWS CodeBuild`
   - **Region**: `us-east-1`
   - **Project name**: `webapp-build`
   - **Build type**: `Single build`

6.6. En **"Deploy stage"**:
   - **Deploy provider**: `Amazon ECS`
   - **Region**: `us-east-1`
   - **Cluster name**: `my-cluster`
   - **Service name**: `my-webapp-service`
   - **Image definitions file**: `imagedefinitions.json`

6.7. Haz clic en **"Create pipeline"**.

---

### Paso 7: Probar el Pipeline Manualmente

7.1. En la consola de CodePipeline, selecciona tu pipeline `webapp-cicd`.

7.2. Haz clic en el botón **"Release change"** para iniciar el pipeline manualmente.

7.3. Monitorea las etapas:
   - **Source**: Debería detectar los cambios en GitHub
   - **Build**: Debería construir la imagen Docker y subirla a ECR
   - **Deploy**: Debería actualizar el service de ECS con la nueva imagen

7.4. Verifica el progreso en cada etapa.

---

### Paso 8: Trigger con Cambio Real

8.1. Haz un cambio en tu código (por ejemplo, modifica un archivo HTML).

8.2. Commit y push el cambio:
   ```bash
   git add .
   git commit -m "Update: trigger pipeline"
   git push origin main
   ```

8.3. Observa cómo CodePipeline detecta automáticamente el cambio y ejecuta el pipeline.

8.4. Verifica que la nueva versión de la aplicación está corriendo en ECS.

---

### Paso 9: Verificar el Despliegue

9.1. Obtén el DNS del ALB:
   ```bash
   aws elbv2 describe-load-balancers --names my-webapp-alb --query 'LoadBalancers[0].DNSName' --output text
   ```

9.2. Accede a la aplicación actualizada (el ALB escucha en el puerto 80):
   ```bash
   curl http://<alb-dns-name>
   ```

9.3. Verifica en la consola de ECS que las tareas fueron actualizadas:
   ```bash
   aws ecs describe-services --cluster my-cluster --services my-webapp-service
   ```

9.4. Revisa los logs del pipeline en CodeBuild para verificar que el build fue exitoso.

---

## Criterios de Verificación

Al finalizar este lab, debes poder confirmar que:

- [ ] El CodeBuild project `webapp-build` fue creado exitosamente
- [ ] El archivo `buildspec.yml` está en el repositorio y es válido
- [ ] El CodePipeline `webapp-cicd` tiene 3 etapas: Source, Build, Deploy
- [ ] El pipeline puede ejecutarse manualmente con "Release change"
- [ ] El pipeline se trigger automáticamente al hacer push a GitHub (rama `main`)
- [ ] La imagen Docker es construida y subida a ECR durante el build
- [ ] El service ECS es actualizado con la nueva imagen después del deploy
- [ ] La aplicación es accesible y muestra la versión actualizada

---

## Errores Comunes y Soluciones

| Error | Causa | Solución |
|-------|-------|----------|
| `Build timeout` | El build tarda más de 60 minutos | Aumenta el timeout en la configuración del proyecto o optimiza el Dockerfile |
| `Access denied error when pushing to ECR` | CodeBuild role sin permisos ECR | Adjunta la política AmazonECRAccessPolicy al service role |
| `Image not found in task definition` | El archivo imagedefinitions.json no se generó | Verifica que el post_build genera este archivo correctamente |
| `InvalidSignatureException` | Credenciales AWS expiradas o mal configuradas | Verifica que AWS_DEFAULT_REGION y AWS_ACCOUNT_ID están definidos en buildspec |
| `Pipeline not triggering` | CloudWatch Events no configurado | Crea manualmente la regla de CloudWatch Events para el repositorio |
| `Deploy stage failed` | Task definition no puede ser actualizada | Verifica que el service tiene el rol de ejecución correcto |
| `docker: command not found` | El Dockerfile no está en la raíz del repo | Asegúrate de que el Dockerfile esté en la raíz, no en subcarpetas |
| `No such file or directory: buildspec.yml` | buildspec.yml no está en la raíz | El buildspec.yml debe estar en la raíz del repositorio |

---

## Notas Importantes sobre la Estructura del Repositorio

**Estructura esperada del repositorio `webapp-repo` en GitHub:**
```
webapp-repo/
├── Dockerfile              # En la raíz (requerido)
├── buildspec.yml           # En la raíz (requerido)
├── package.json
├── src/
│   └── index.js
└── public/
    └── index.html
```

**⚠️ Importante**: 
- El `Dockerfile` y `buildspec.yml` deben estar en la **raíz** del repositorio
- No uses subcarpetas como `app/` o `docker/` en el repositorio GitHub
- Los archivos en `lab-2/docker/` y `lab-2/pipeline/` son ejemplos para copiar, no para la estructura del repo

---

## Limpieza de Recursos

Para evitar costos innecesarios, elimina los recursos creados:

```bash
# Eliminar el pipeline
aws codepipeline delete-pipeline --name webapp-cicd

# Eliminar el proyecto de CodeBuild
aws codebuild delete-project --name webapp-build

# Eliminar la CodeStar Connection (opcional, desde la consola):
# Developer Tools > Settings > Connections > github-connection > Delete
# El repositorio GitHub se elimina desde github.com > Settings > Delete this repository

# Vaciar y eliminar el bucket S3
aws s3 rb s3://my-artifacts-bucket-<account-id> --force
```

---

## Referencias

- [AWS CodePipeline Documentation](https://docs.aws.amazon.com/codepipeline/latest/userguide/)
- [AWS CodeBuild Documentation](https://docs.aws.amazon.com/codebuild/latest/userguide/)
- [ECS CodePipeline Deployment](https://docs.aws.amazon.com/AmazonECS/latest/userguide/ecs-cd-pipeline.html)
