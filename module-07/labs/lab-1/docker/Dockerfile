# ============================================
# Dockerfile - Lab 7.1 ECS Fargate
# Aplicación Web con Nginx
# ============================================

# Usar imagen base oficial de nginx
FROM nginx:1.25-alpine

# ============================================
# Metadata
# ============================================
LABEL maintainer="AWS Academy"
LABEL description="Web application for ECS Fargate deployment"
LABEL version="1.0"

# ============================================
# Variables de Build
# ============================================
ARG NODE_ENV=production
ARG API_URL=http://api-service.default.svc.cluster.local:8000

# ============================================
# Actualizar nginx.conf
# ============================================
COPY docker/nginx.conf /etc/nginx/nginx.conf

# ============================================
# Directorio de trabajo
# ============================================
WORKDIR /usr/share/nginx/html

# ============================================
# Copiar archivos estáticos
# ============================================
COPY app/dist /usr/share/nginx/html

# ============================================
# Scripts de health check
# ============================================
COPY docker/health-check.sh /usr/local/bin/health-check
RUN chmod +x /usr/local/bin/health-check

# ============================================
# Variables de entorno
# ============================================
ENV NODE_ENV=${NODE_ENV} \
    API_URL=${API_URL}

# ============================================
# Exponer puertos
# ============================================
EXPOSE 80 443

# ============================================
# Healthcheck
# ============================================
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD /usr/local/bin/health-check

# ============================================
# Usuario no root (buenas prácticas)
# ============================================
RUN addgroup -g 1001 -S appgroup && \
    adduser -u 1001 -S appuser -G appgroup

USER appuser

# ============================================
# Comando de inicio
# ============================================
CMD ["nginx", "-g", "daemon off;"]
