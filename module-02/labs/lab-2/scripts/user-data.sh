#!/bin/bash
# ============================================
# User Data Script - Lab 2.2
# EC2 Instance Setup con Apache y Storage EBS
# ============================================

# Exit on any error
set -e

echo "=== Iniciando configuración de EC2 ==="

# ============================================
# Actualizar sistema e instalar dependencias
# ============================================
echo "1. Actualizando sistema..."
yum update -y

echo "2. Instalando Apache y utilidades..."
yum install -y httpd php mysql php-mysql amazon-efs-utils nfs-utils

# ============================================
# Configurar y montar EBS Volume
# ============================================
echo "3. Configurando EBS Volume..."

# Obtener información del volumen desde los metadatos
EBS_DEVICE="/dev/xvdb"
EBS_MOUNT_POINT="/var/www/html/data"

# Verificar si el dispositivo existe
if [ -b ${EBS_DEVICE} ]; then
    echo "Dispositivo ${EBS_DEVICE} encontrado"
    
    # Formatear si no tiene filesystem
    if ! file -s ${EBS_DEVICE} | grep -q "filesystem"; then
        echo "Formateando ${EBS_DEVICE}..."
        mkfs -t ext4 ${EBS_DEVICE}
    fi
    
    # Crear directorio de montaje
    mkdir -p ${EBS_MOUNT_POINT}
    
    # Montar el volumen
    mount ${EBS_DEVICE} ${EBS_MOUNT_POINT}
    
    # Agregar al fstab para montaje automático
    echo "${EBS_DEVICE} ${EBS_MOUNT_POINT} ext4 defaults,nofail 0 2" >> /etc/fstab
    
    # Establecer permisos
    chmod 777 ${EBS_MOUNT_POINT}
    
    echo "EBS Volume montado en ${EBS_MOUNT_POINT}"
else
    echo "ADVERTENCIA: Dispositivo ${EBS_DEVICE} no encontrado"
fi

# ============================================
# Configurar Apache
# ============================================
echo "4. Configurando Apache..."

# Habilitar e iniciar Apache
systemctl enable httpd
systemctl start httpd

# Configurar firewall (si está disponible)
if command -v firewall-cmd &> /dev/null; then
    firewall-cmd --permanent --add-service=http
    firewall-cmd --permanent --add-service=https
    firewall-cmd --reload
fi

# ============================================
# Crear página web de prueba
# ============================================
echo "5. Creando página web de prueba..."

cat > /var/www/html/index.html << 'EOF'
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>AWS Academy - Lab 2.2</title>
    <style>
        body { font-family: Arial, sans-serif; max-width: 800px; margin: 50px auto; padding: 20px; }
        h1 { color: #232f3e; }
        .info { background: #f0f0f0; padding: 15px; border-radius: 5px; }
        .success { color: green; font-weight: bold; }
    </style>
</head>
<body>
    <h1>Bienvenido al Lab 2.2 - EC2 con EBS</h1>
    <div class="info">
        <p class="success">✓ Apache instalado y ejecutándose</p>
        <p>Instancia ID: <strong>$(curl -s http://169.254.169.254/latest/meta-data/instance-id)</strong></p>
        <p>Zona de disponibilidad: <strong>$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)</strong></p>
        <p>Dirección IP privada: <strong>$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)</strong></p>
    </div>
    <h2>Datos del EBS Volume</h2>
    <pre>$(df -h /var/www/html/data 2>/dev/null || echo "EBS no montado")</pre>
</body>
</html>
EOF

# ============================================
# Crear script de health check
# ============================================
cat > /var/www/html/health.html << 'EOF'
OK
EOF

# ============================================
# Configurar permisos
# ============================================
echo "6. Configurando permisos..."
chown -R apache:apache /var/www/html
chmod -R 755 /var/www/html

# ============================================
# Verificar instalación
# ============================================
echo "7. Verificando instalación..."
httpd -v
systemctl status httpd | head -5

echo ""
echo "=== Configuración completada ==="
echo "La aplicación está disponible en http://$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)/"
