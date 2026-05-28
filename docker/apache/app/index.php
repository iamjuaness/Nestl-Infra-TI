<?php
/**
 * Nestlé - Panel de Infraestructura TI
 * Proyecto Final: Administración de Infraestructura
 */

// Configuración de base de datos
$db_host = getenv('DB_HOST') ?: 'db_primary';
$db_name = getenv('DB_NAME') ?: 'nestle_db';
$db_user = getenv('DB_USER') ?: 'nestle_user';
$db_pass = getenv('DB_PASS') ?: 'nestle_secure_2026';

// Opciones PDO para conexión segura
$options = [
    PDO::MYSQL_ATTR_SSL_VERIFY_SERVER_CERT => false,
    PDO::MYSQL_ATTR_SSL_CA => '/etc/ssl/certs/ca-certificates.crt',
    PDO::MYSQL_ATTR_SSL_CERT => '/etc/ssl/certs/client-cert.pem',
    PDO::MYSQL_ATTR_SSL_KEY => '/etc/ssl/private/client-key.pem',
    PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
    PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
    PDO::ATTR_EMULATE_PREPARES => false,
];

// Conexión a base de datos con SSL
try {
    $dsn = "mysql:host=$db_host;dbname=$db_name;charset=utf8mb4";
    $pdo = new PDO($dsn, $db_user, $db_pass, $options);
    $db_status = "✓ Conectado (SSL)";
    $db_color = "#28a745";
} catch (PDOException $e) {
    // Fallback: intentar sin SSL si no hay certificados configurados
    try {
        $pdo_fallback = new PDO("mysql:host=$db_host;dbname=$db_name;charset=utf8mb4", $db_user, $db_pass);
        $pdo_fallback->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
        $pdo = $pdo_fallback;
        $db_status = "✓ Conectado (sin SSL)";
        $db_color = "#ffc107";
    } catch (PDOException $e2) {
        $db_status = "✗ Error: " . $e2->getMessage();
        $db_color = "#dc3545";
    }
}

// Información del servidor
$server_role = getenv('SERVER_ROLE') ?: 'unknown';
$server_ip = $_SERVER['SERVER_ADDR'] ?? 'N/A';
$hostname = gethostname();
?>
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Nestlé - Infraestructura TI</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #1e3c72 0%, #2a5298 100%);
            min-height: 100vh;
            color: #333;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
        }
        .header {
            text-align: center;
            padding: 40px 0;
            color: white;
        }
        .header h1 {
            font-size: 2.5em;
            margin-bottom: 10px;
        }
        .header p {
            font-size: 1.1em;
            opacity: 0.9;
        }
        .status-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
            gap: 20px;
            margin-top: 30px;
        }
        .card {
            background: white;
            border-radius: 12px;
            padding: 25px;
            box-shadow: 0 4px 15px rgba(0,0,0,0.1);
            transition: transform 0.3s;
        }
        .card:hover {
            transform: translateY(-5px);
        }
        .card h3 {
            color: #1e3c72;
            margin-bottom: 15px;
            font-size: 1.2em;
        }
        .status-item {
            display: flex;
            justify-content: space-between;
            padding: 8px 0;
            border-bottom: 1px solid #eee;
        }
        .status-item:last-child { border-bottom: none; }
        .badge {
            padding: 4px 12px;
            border-radius: 20px;
            font-size: 0.85em;
            font-weight: 600;
        }
        .badge-success { background: #d4edda; color: #155724; }
        .badge-warning { background: #fff3cd; color: #856404; }
        .badge-danger { background: #f8d7da; color: #721c24; }
        .badge-info { background: #d1ecf1; color: #0c5460; }
        .footer {
            text-align: center;
            padding: 30px;
            color: white;
            opacity: 0.8;
        }
        .server-info {
            background: rgba(255,255,255,0.1);
            padding: 15px;
            border-radius: 8px;
            margin-top: 20px;
            color: white;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 10px;
        }
        th, td {
            padding: 10px;
            text-align: left;
            border-bottom: 1px solid #eee;
        }
        th {
            color: #1e3c72;
            font-weight: 600;
        }
        .alert-box {
            background: #fff3cd;
            border: 1px solid #ffc107;
            border-radius: 8px;
            padding: 15px;
            margin: 20px 0;
            color: #856404;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🏭 Nestlé</h1>
            <p>Panel de Monitoreo de Infraestructura TI</p>
            <div class="server-info">
                <strong>Servidor:</strong> <?php echo htmlspecialchars($hostname); ?> | 
                <strong>Rol:</strong> <?php echo htmlspecialchars($server_role); ?> | 
                <strong>IP:</strong> <?php echo htmlspecialchars($server_ip); ?>
            </div>
        </div>

        <?php if (strpos($db_status, 'sin SSL') !== false): ?>
        <div class="alert-box">
            <strong>⚠ Nota de Seguridad:</strong> La conexión a la base de datos no utiliza SSL. 
            Esto es normal en entornos de desarrollo. En producción, habilite require_secure_transport=ON 
            y configure certificados SSL para MySQL.
        </div>
        <?php endif; ?>

        <div class="status-grid">
            <div class="card">
                <h3>🗄️ Base de Datos</h3>
                <div class="status-item">
                    <span>Estado</span>
                    <span class="badge" style="background: <?php echo $db_color; ?>20; color: <?php echo $db_color; ?>">
                        <?php echo $db_status; ?>
                    </span>
                </div>
                <div class="status-item">
                    <span>Host</span>
                    <span class="badge badge-success"><?php echo $db_host; ?></span>
                </div>
                <div class="status-item">
                    <span>Base de datos</span>
                    <span class="badge badge-success"><?php echo $db_name; ?></span>
                </div>
            </div>

            <div class="card">
                <h3>🖥️ Servidor Web</h3>
                <div class="status-item">
                    <span>Apache</span>
                    <span class="badge badge-success">✓ Activo</span>
                </div>
                <div class="status-item">
                    <span>PHP</span>
                    <span class="badge badge-success"><?php echo phpversion(); ?></span>
                </div>
                <div class="status-item">
                    <span>Rol</span>
                    <span class="badge badge-warning"><?php echo $server_role; ?></span>
                </div>
            </div>

            <div class="card">
                <h3>🔒 Seguridad</h3>
                <div class="status-item">
                    <span>SSL/TLS (Web)</span>
                    <span class="badge badge-success">✓ Habilitado</span>
                </div>
                <div class="status-item">
                    <span>Firewall</span>
                    <span class="badge badge-success">✓ Activo</span>
                </div>
                <div class="status-item">
                    <span>Headers</span>
                    <span class="badge badge-success">✓ Configurados</span>
                </div>
            </div>

            <div class="card">
                <h3>📊 Monitoreo</h3>
                <div class="status-item">
                    <span>Prometheus</span>
                    <span class="badge badge-success">:9090</span>
                </div>
                <div class="status-item">
                    <span>Grafana</span>
                    <span class="badge badge-success">:3000</span>
                </div>
                <div class="status-item">
                    <span>Logs</span>
                    <span class="badge badge-success">✓ Centralizados</span>
                </div>
            </div>
        </div>

        <?php if (isset($pdo) && strpos($db_status, 'Error') === false): ?>
        <div class="card" style="margin-top: 30px;">
            <h3>👥 Empleados del Departamento de TI</h3>
            <table>
                <thead>
                    <tr>
                        <th>Nombre</th>
                        <th>Departamento</th>
                        <th>Cargo</th>
                        <th>Email</th>
                    </tr>
                </thead>
                <tbody>
                    <?php
                    $stmt = $pdo->query("SELECT nombre, departamento, cargo, email FROM empleados WHERE activo = TRUE");
                    while ($row = $stmt->fetch(PDO::FETCH_ASSOC)):
                    ?>
                    <tr>
                        <td><?php echo htmlspecialchars($row['nombre']); ?></td>
                        <td><?php echo htmlspecialchars($row['departamento']); ?></td>
                        <td><?php echo htmlspecialchars($row['cargo']); ?></td>
                        <td><?php echo htmlspecialchars($row['email']); ?></td>
                    </tr>
                    <?php endwhile; ?>
                </tbody>
            </table>
        </div>

        <div class="card" style="margin-top: 20px;">
            <h3>📦 Inventario de Equipos</h3>
            <table>
                <thead>
                    <tr>
                        <th>Producto</th>
                        <th>Categoría</th>
                        <th>Cantidad</th>
                        <th>Ubicación</th>
                    </tr>
                </thead>
                <tbody>
                    <?php
                    $stmt = $pdo->query("SELECT producto, categoria, cantidad, ubicacion FROM inventario");
                    while ($row = $stmt->fetch(PDO::FETCH_ASSOC)):
                    ?>
                    <tr>
                        <td><?php echo htmlspecialchars($row['producto']); ?></td>
                        <td><?php echo htmlspecialchars($row['categoria']); ?></td>
                        <td><?php echo htmlspecialchars($row['cantidad']); ?></td>
                        <td><?php echo htmlspecialchars($row['ubicacion']); ?></td>
                    </tr>
                    <?php endwhile; ?>
                </tbody>
            </table>
        </div>
        <?php endif; ?>

        <div class="footer">
            <p>© 2026 Nestlé - Infraestructura TI | Proyecto Final</p>
            <p>Documentación: <a href="/docs" style="color: #fff;">Documento Técnico</a></p>
        </div>
    </div>
</body>
</html>