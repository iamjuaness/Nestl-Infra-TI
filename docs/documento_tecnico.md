# DOCUMENTO TÉCNICO - INFRAESTRUCTURA TI NESTLÉ

**Proyecto Final: Administración de Infraestructura TI**  
**Fecha:** Mayo 2026  
**Versión:** 1.0  
**Equipo:** Juan Esteban Cardona, Juan Esteban Ramirez 

---

## 1. RESUMEN EJECUTIVO

Este documento describe el diseño, implementación y operación de la infraestructura TI propuesta para Nestlé. La solución está basada en contenedores Docker, implementa alta disponibilidad, seguridad por capas, monitoreo continuo y automatización de procesos críticos.

---

## 2. ARQUITECTURA GENERAL

### 2.1 Diagrama de Red

```
                    INTERNET
                       |
                       v
                +-------------+
                |   ROUTER    |  192.168.1.1
                +------+------+
                       |
         +-------------+-------------+
         |                           |
    +----v----+                 +----v----+
    |  DMZ    |                 |  LAN    |
    | .10/24  |                 | .20/24  |
    +----+----+                 +----+----+
         |                           |
    +----v----+                 +----v----+
    | NGINX LB|                 | MGMT    |
    | :80/443 |                 | .30/24  |
    +----+----+                 +----+----+
         |                           |
    +----v----------------+     +----v----+
    |                     |     | BASTION |
    |  WEB CLUSTER        |     | SSH:2222|
    |  +-------------+    |     +----+----+
    |  | WEB PRIMARY |    |          |
    |  | :80         |    |     +----v---------+
    |  +-------------+    |     | MONITOREO    |
    |  +-------------+    |     | Prometheus   |
    |  | WEB SECONDARY|   |     | Grafana      |
    |  | :80         |    |     +--------------+
    |  +-------------+    |
    +---------+-----------+
              |
    +---------v-----------+
    |    BACKEND NET      |
    |    172.20.20.0/24   |
    |                     |
    |  +-------------+    |
    |  | DB PRIMARY  |    |
    |  | MySQL:3306  |    |
    |  +-------------+    |
    |  +-------------+    |
    |  | DB REPLICA  |    |
    |  | MySQL:3306  |    |
    |  +-------------+    |
    |  +-------------+    |
    |  | FILE SERVER |    |
    |  | SMB:445     |    |
    |  +-------------+    |
    |  +-------------+    |
    |  | NTP         |    |
    |  | :123/udp    |    |
    |  +-------------+    |
    +---------------------+
```

### 2.2 Segmentación de Red

| Segmento | Subred | Propósito | Servicios |
|----------|--------|-----------|-----------|
| Frontend | 172.20.10.0/24 | Acceso público | Nginx LB, Web servers |
| Backend | 172.20.20.0/24 | Comunicación interna | DB, File, NTP |
| Management | 172.20.30.0/24 | Administración | SSH, Prometheus, Grafana |

### 2.3 Direccionamiento IP

| Servidor | IP | Servicio | Puerto |
|----------|-----|----------|--------|
| nginx_lb | 172.20.10.10 | HTTP/HTTPS | 80/443 |
| web_primary | 172.20.10.11 | Apache | 80 |
| web_secondary | 172.20.10.12 | Apache | 80 |
| db_primary | 172.20.20.10 | MySQL | 3306 |
| db_replica | 172.20.20.11 | MySQL Replica | 3306 |
| fileserver | 172.20.20.20 | Samba | 139/445 |
| ntp | 172.20.20.30 | NTP | 123/udp |
| ssh_bastion | 172.20.30.10 | SSH | 2222 |
| prometheus | 172.20.30.20 | Prometheus | 9090 |
| grafana | 172.20.30.21 | Grafana | 3000 |

---

## 3. JUSTIFICACIÓN TÉCNICA

### 3.1 Docker y Docker Compose
- **Aislamiento:** Cada servicio corre en su propio contenedor, evitando conflictos de dependencias.
- **Portabilidad:** La infraestructura puede replicarse en cualquier ambiente con Docker.
- **Escalabilidad:** Fácil replicación de servicios web mediante `docker-compose up --scale`.
- **Rollback:** Imágenes versionadas permiten revertir cambios rápidamente.

### 3.2 Alta Disponibilidad
- **Balanceo de carga:** Nginx distribuye tráfico entre dos servidores web.
- **Replicación MySQL:** Base de datos principal con réplica para lecturas y failover.
- **Healthchecks:** Docker verifica automáticamente la salud de cada contenedor.
- **Restart policies:** Los servicios se reinician automáticamente ante fallos.

### 3.3 RAID y LVM
- **RAID 1 (Simulado):** Los volúmenes Docker utilizan `local` driver con backups automáticos.
- **LVM:** Permite redimensionar volúmenes de datos sin interrumpir servicios.
- **Justificación:** Aunque en contenedores el storage es abstracto, los volúmenes persistentes (`nestle_db_data`, `nestle_web_data`) simulan esta capa de redundancia.

---

## 4. SEGURIDAD

### 4.1 Firewall (UFW/iptables)
- Política por defecto: DENY all
- Solo puertos necesarios expuestos
- Conexiones SSH restringidas al bastion

### 4.2 Gestión de Usuarios y Permisos
- **Usuarios del sistema:** `nestle_admin` (administrador), `nestle_user` (operador)
- **SETUID (4755):** Script de backup ejecuta con privilegios elevados
- **SETGID (2755):** Script de monitoreo hereda grupo para acceso a logs
- **Sticky Bit (1777):** Directorio `/shared` permite escritura pero no borrado de archivos ajenos

### 4.3 SSL/TLS
- Certificados autofirmados para desarrollo
- TLS 1.2/1.3 obligatorio
- Headers de seguridad (HSTS, XSS Protection, etc.)

---

## 5. SERVICIOS IMPLEMENTADOS

| Servicio | Tecnología | Justificación |
|----------|-----------|---------------|
| Web | Apache + PHP | Amplia compatibilidad, módulos de seguridad |
| Base de Datos | MySQL 8.0 | Rendimiento, replicación nativa |
| SSH | OpenSSH (Bastion) | Acceso seguro, autenticación por clave |
| NTP | cturra/ntp | Sincronización horaria crítica para logs |
| Archivos | Samba | Compatibilidad Windows/Linux, cifrado SMB3 |
| Monitoreo | Prometheus + Grafana | Métricas en tiempo real, dashboards |

---

## 6. AUTOMATIZACIÓN

### 6.1 Scripts Bash
1. **backup_nestle.sh:** Backup completo (DB, web, configs, logs) con retención de 30 días
2. **monitor_nestle.sh:** Monitoreo de recursos, contenedores, red y base de datos
3. **deploy_nestle.sh:** Despliegue completo con verificación de requisitos y seguridad

### 6.2 Cron Jobs
- Backup diario: 2:00 AM
- Monitoreo: Cada 5 minutos
- Limpieza de logs: Domingos 3:00 AM

---

## 7. MONITOREO

### 7.1 Métricas Recolectadas
- Uso de CPU, Memoria, Disco
- Estado de contenedores Docker
- Conexiones de red activas
- Estado de replicación MySQL
- Logs de errores del sistema

### 7.2 Herramientas
- **top/htop:** Recursos en tiempo real
- **journalctl:** Logs centralizados
- **Prometheus:** Métricas y alertas
- **Grafana:** Visualización y dashboards

---

## 8. ALTA DISPONIBILIDAD

### 8.1 Estrategias
1. **Balanceo de carga:** Nginx distribuye tráfico entre múltiples web servers
2. **Replicación de BD:** MySQL master-slave para lecturas distribuidas
3. **Healthchecks:** Verificación automática de salud de servicios
4. **Auto-restart:** Políticas de reinicio automático en Docker

### 8.2 Recuperación ante Fallos
- **Escenario 1:** Web primary caído → Nginx redirige a secondary
- **Escenario 2:** DB primary caído → Promoción manual de replica a primary
- **Escenario 3:** Contenedor caído → Docker restart policy lo recupera
- **Escenario 4:** Pérdida total de datos → Restauración desde backup

---

## 9. COMANDOS ÚTILES

```bash
# Desplegar infraestructura
./scripts/deploy_nestle.sh

# Ver estado de servicios
docker-compose -f /docker-compose.yml ps

# Ver logs
docker-compose -f /docker-compose.yml logs -f

# Escalar servicios web
docker-compose -f /docker-compose.yml up -d --scale web_primary=2

# Backup manual
./scripts/backup_nestle.sh

# Monitoreo manual
./scripts/monitor_nestle.sh

# Acceso a base de datos
docker exec -it nestle_db_primary mysql -u root -p

# Ver métricas de Prometheus
curl http://localhost:9090/api/v1/status/targets
```

---

## 10. CONCLUSIONES

La infraestructura propuesta cumple con los requisitos de funcionalidad, seguridad y escalabilidad. La contenerización con Docker permite un despliegue ágil y reproducible, mientras que las capas de seguridad (firewall, permisos especiales, SSL) protegen los activos de información. La automatización mediante scripts Bash reduce la intervención manual y el riesgo de error humano.

---
