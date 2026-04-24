# ============================================
# Dockerfile para CI/CD - Lab 7.2
# Build multi-stage para aplicación Node.js
# ============================================

# ============================================
# Stage 1: Build
# ============================================
FROM node:22-alpine AS builder

WORKDIR /build

# Copiar package files
COPY package*.json ./

# Instalar dependencias (incluyendo devDependencies para el build)
RUN npm ci

# Copiar código fuente
COPY src/ ./src/
COPY public/ ./public/

# Build de la aplicación
RUN npm run build

# ============================================
# Stage 2: Production
# ============================================
FROM node:22-alpine AS production

# Crear usuario no-root
RUN addgroup -g 1001 -S nodejs && \
    adduser -u 1001 -S nodejs -G nodejs

WORKDIR /app

# Copiar archivos del stage de build
COPY --from=builder /build/dist ./dist
COPY --from=builder /build/node_modules ./node_modules
COPY --from=builder /build/package.json ./

# Configurar usuario
USER nodejs

# Variables de entorno
ENV NODE_ENV=production \
    PORT=3000 \
    HOST=0.0.0.0

# Exponer puerto
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD node -e "require('http').get('http://localhost:3000/health', (r) => process.exit(r.statusCode === 200 ? 0 : 1))"

# Iniciar aplicación
CMD ["node", "dist/index.js"]
