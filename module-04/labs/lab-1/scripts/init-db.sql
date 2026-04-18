-- ============================================
-- Script de Inicialización BD - Lab 4.1
-- Arquitectura Web 3-Capas con RDS Multi-AZ
-- ============================================

-- Crear base de datos para la aplicación
CREATE DATABASE IF NOT EXISTS webapp;

USE webapp;

-- ============================================
-- Tabla de Usuarios
-- ============================================
CREATE TABLE IF NOT EXISTS users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    email VARCHAR(100) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE,
    INDEX idx_email (email),
    INDEX idx_username (username)
) ENGINE=InnoDB;

-- ============================================
-- Tabla de Categorías
-- ============================================
CREATE TABLE IF NOT EXISTS categories (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- ============================================
-- Tabla de Productos
-- ============================================
CREATE TABLE IF NOT EXISTS products (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    description TEXT,
    price DECIMAL(10, 2) NOT NULL,
    stock INT DEFAULT 0,
    category_id INT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE SET NULL,
    INDEX idx_category (category_id),
    INDEX idx_price (price)
) ENGINE=InnoDB;

-- ============================================
-- Tabla de Órdenes
-- ============================================
CREATE TABLE IF NOT EXISTS orders (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    total_amount DECIMAL(10, 2) NOT NULL,
    status ENUM('pending', 'processing', 'shipped', 'delivered', 'cancelled') DEFAULT 'pending',
    shipping_address TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_user (user_id),
    INDEX idx_status (status),
    INDEX idx_created (created_at)
) ENGINE=InnoDB;

-- ============================================
-- Tabla de Detalles de Orden
-- ============================================
CREATE TABLE IF NOT EXISTS order_items (
    id INT AUTO_INCREMENT PRIMARY KEY,
    order_id INT NOT NULL,
    product_id INT NOT NULL,
    quantity INT NOT NULL DEFAULT 1,
    unit_price DECIMAL(10, 2) NOT NULL,
    FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
    INDEX idx_order (order_id),
    INDEX idx_product (product_id)
) ENGINE=InnoDB;

-- ============================================
-- Datos de Prueba
-- ============================================

-- Insertar usuarios
INSERT INTO users (username, email, password_hash) VALUES
('admin', 'admin@example.com', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/X4.S.G0h7Xrxu6U3u'),
('juanp', 'juan@example.com', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/X4.S.G0h7Xrxu6U3u'),
('mariag', 'maria@example.com', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/X4.S.G0h7Xrxu6U3u');

-- Insertar categorías
INSERT INTO categories (name, description) VALUES
('Electrónica', 'Dispositivos electrónicos y accesorios'),
('Ropa', 'Vestimenta y accesorios de moda'),
('Hogar', 'Artículos para el hogar y jardín');

-- Insertar productos
INSERT INTO products (name, description, price, stock, category_id) VALUES
('Laptop HP 15"', 'Laptop con 8GB RAM, 256GB SSD', 599.99, 50, 1),
('Smartphone Samsung', 'Galaxy S21 con 128GB', 699.99, 30, 1),
('Camisa Casual', 'Camisa de algodón para hombre', 29.99, 100, 2),
('Silla de Oficina', 'Silla ergonómica con soporte lumbar', 149.99, 25, 3);

-- Verificar replicación Multi-AZ
-- Ejecutar en Primary: CREATE TABLE replication_test (id INT PRIMARY KEY, test_data VARCHAR(100));
-- Verificar en Standby que aparece automáticamente
