-- Inicialización de base de datos Nestlé
-- Tablas y datos de ejemplo

USE nestle_db;

-- Tabla de empleados
CREATE TABLE IF NOT EXISTS empleados (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    departamento VARCHAR(50),
    cargo VARCHAR(50),
    email VARCHAR(100) UNIQUE,
    fecha_ingreso DATE,
    activo BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tabla de inventario
CREATE TABLE IF NOT EXISTS inventario (
    id INT AUTO_INCREMENT PRIMARY KEY,
    producto VARCHAR(100) NOT NULL,
    categoria VARCHAR(50),
    cantidad INT DEFAULT 0,
    ubicacion VARCHAR(50),
    fecha_actualizacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Tabla de logs del sistema
CREATE TABLE IF NOT EXISTS system_logs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    servicio VARCHAR(50),
    nivel VARCHAR(20),
    mensaje TEXT,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insertar datos de ejemplo
INSERT INTO empleados (nombre, departamento, cargo, email, fecha_ingreso) VALUES
('Juan Pérez', 'TI', 'Administrador de Sistemas', 'juan.perez@nestle.local', '2020-01-15'),
('María García', 'TI', 'Ingeniera de Redes', 'maria.garcia@nestle.local', '2019-06-20'),
('Carlos López', 'Seguridad', 'Analista de Seguridad', 'carlos.lopez@nestle.local', '2021-03-10'),
('Ana Martínez', 'Operaciones', 'Operador de Datacenter', 'ana.martinez@nestle.local', '2022-01-05');

INSERT INTO inventario (producto, categoria, cantidad, ubicacion) VALUES
('Servidor Dell R740', 'Hardware', 5, 'Datacenter Principal'),
('Switch Cisco 2960', 'Redes', 12, 'Almacén TI'),
('Firewall Fortinet', 'Seguridad', 3, 'Datacenter Principal'),
('UPS APC 3000VA', 'Infraestructura', 8, 'Sala de Servidores');

-- Crear usuario de replicación
CREATE USER IF NOT EXISTS 'repl_user'@'%' IDENTIFIED BY 'repl_secure_2026';
GRANT REPLICATION SLAVE ON *.* TO 'repl_user'@'%';

-- Crear usuario de monitoreo
CREATE USER IF NOT EXISTS 'monitor'@'%' IDENTIFIED BY 'monitor_2026';
GRANT SELECT, PROCESS, REPLICATION CLIENT ON *.* TO 'monitor'@'%';

FLUSH PRIVILEGES;
