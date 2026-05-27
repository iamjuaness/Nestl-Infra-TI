#!/bin/bash
#===============================================================================
# SCRIPT: deploy_nestle.sh
# DESCRIPCIÓN: Despliegue automatizado de infraestructura Nestlé
# AUTOR: Equipo Infraestructura TI - Nestlé
#===============================================================================

set -euo pipefail

LOG_FILE="/var/log/nestle/deploy.log"
mkdir -p "$(dirname "$LOG_FILE")"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV="${1:-production}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

error_exit() {
    log "${RED}ERROR: $1${NC}"
    exit 1
}

clear
log "${CYAN}========================================${NC}"
log "${CYAN}  DESPLIEGUE INFRAESTRUCTURA NESTLÉ     ${NC}"
log "${CYAN}  Entorno: $ENV                          ${NC}"
log "${CYAN}========================================${NC}"

#-------------------------------------------------------------------------------
# 1. VERIFICACIÓN DE REQUISITOS
#-------------------------------------------------------------------------------
log "${YELLOW}--- VERIFICANDO REQUISITOS ---${NC}"

# Docker
if ! command -v docker &> /dev/null; then
    error_exit "Docker no está instalado"
fi
DOCKER_VERSION=$(docker --version)
log "${GREEN}✓ $DOCKER_VERSION${NC}"

# Docker Compose
if ! command -v docker-compose &> /dev/null; then
    error_exit "Docker Compose no está instalado"
fi
COMPOSE_VERSION=$(docker-compose --version)
log "${GREEN}✓ $COMPOSE_VERSION${NC}"

# Recursos disponibles
AVAILABLE_RAM=$(free -m | awk 'NR==2{printf "%.0f", $7}')
AVAILABLE_DISK=$(df -m / | awk 'NR==2{printf "%.0f", $4}')
log "RAM disponible: ${AVAILABLE_RAM}MB"
log "Disco disponible: ${AVAILABLE_DISK}MB"

if [ "$AVAILABLE_RAM" -lt 2048 ]; then
    log "${YELLOW}⚠ RAM insuficiente. Se recomiendan al menos 2GB${NC}"
fi

#-------------------------------------------------------------------------------
# 2. CONFIGURACIÓN DE SEGURIDAD
#-------------------------------------------------------------------------------
log "${YELLOW}--- CONFIGURANDO SEGURIDAD ---${NC}"

# Crear usuarios del sistema si no existen
if ! id "nestle_admin" &>/dev/null; then
    sudo useradd -m -s /bin/bash nestle_admin 2>/dev/null || true
    sudo usermod -aG docker nestle_admin 2>/dev/null || true
    log "${GREEN}✓ Usuario nestle_admin creado${NC}"
fi

if ! id "nestle_user" &>/dev/null; then
    sudo useradd -m -s /bin/bash nestle_user 2>/dev/null || true
    log "${GREEN}✓ Usuario nestle_user creado${NC}"
fi

# Configurar firewall (ufw)
if command -v ufw &> /dev/null; then
    sudo ufw --force reset
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    sudo ufw allow 22/tcp
    sudo ufw allow 80/tcp
    sudo ufw allow 443/tcp
    sudo ufw allow 2222/tcp
    sudo ufw allow 3306/tcp
    sudo ufw allow 123/udp
    sudo ufw allow 139/tcp
    sudo ufw allow 445/tcp
    sudo ufw allow 9090/tcp
    sudo ufw allow 3000/tcp
    sudo ufw --force enable
    log "${GREEN}✓ Firewall configurado${NC}"
else
    log "${YELLOW}⚠ UFW no disponible, configurando iptables...${NC}"
    sudo iptables -F
    sudo iptables -P INPUT DROP
    sudo iptables -P FORWARD DROP
    sudo iptables -P OUTPUT ACCEPT
    sudo iptables -A INPUT -i lo -j ACCEPT
    sudo iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
    sudo iptables -A INPUT -p tcp --dport 22 -j ACCEPT
    sudo iptables -A INPUT -p tcp --dport 80 -j ACCEPT
    sudo iptables -A INPUT -p tcp --dport 443 -j ACCEPT
    sudo iptables -A INPUT -p tcp --dport 2222 -j ACCEPT
    sudo iptables -A INPUT -p tcp --dport 3306 -j ACCEPT
    sudo iptables -A INPUT -p udp --dport 123 -j ACCEPT
    sudo iptables -A INPUT -p tcp --dport 139 -j ACCEPT
    sudo iptables -A INPUT -p tcp --dport 445 -j ACCEPT
    sudo iptables -A INPUT -p tcp --dport 9090 -j ACCEPT
    sudo iptables -A INPUT -p tcp --dport 3000 -j ACCEPT
    log "${GREEN}✓ Iptables configurado${NC}"
fi

#-------------------------------------------------------------------------------
# 3. CONFIGURACIÓN DE DIRECTORIOS
#-------------------------------------------------------------------------------
log "${YELLOW}--- CONFIGURANDO DIRECTORIOS ---${NC}"

mkdir -p /var/log/nestle
mkdir -p /backup/nestle
mkdir -p /shared/nestle

# Permisos con SETUID, SETGID y Sticky Bit
sudo chmod 755 /var/log/nestle
sudo chmod 755 /backup/nestle
sudo chmod 1777 /shared/nestle  # Sticky bit

# Configurar permisos especiales en scripts críticos
sudo chmod 4755 "$PROJECT_DIR/scripts/backup_nestle.sh" 2>/dev/null || true  # SETUID
sudo chmod 2755 "$PROJECT_DIR/scripts/monitor_nestle.sh" 2>/dev/null || true  # SETGID

log "${GREEN}✓ Directorios y permisos configurados${NC}"

#-------------------------------------------------------------------------------
# 4. GENERAR CERTIFICADOS SSL
#-------------------------------------------------------------------------------
log "${YELLOW}--- GENERANDO CERTIFICADOS SSL ---${NC}"

SSL_DIR="$PROJECT_DIR/configs/nginx/ssl"
mkdir -p "$SSL_DIR"

if [ ! -f "$SSL_DIR/nestle.crt" ]; then
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "$SSL_DIR/nestle.key" \
        -out "$SSL_DIR/nestle.crt" \
        -subj "/C=CO/ST=Bogota/L=Bogota/O=Nestle/OU=IT/CN=nestle.local" \
        2>/dev/null
    log "${GREEN}✓ Certificados SSL generados${NC}"
else
    log "${GREEN}✓ Certificados SSL ya existen${NC}"
fi

#-------------------------------------------------------------------------------
# 5. DESPLIEGUE CON DOCKER COMPOSE
#-------------------------------------------------------------------------------
log "${YELLOW}--- DESPLEGANDO SERVICIOS ---${NC}"

cd "$PROJECT_DIR/docker"

# Detener servicios existentes
log "Deteniendo servicios existentes..."
docker-compose down --remove-orphans 2>/dev/null || true

# Construir imágenes
log "Construyendo imágenes..."
docker-compose build --no-cache

# Iniciar servicios
log "Iniciando servicios..."    
docker-compose up -d

# Esperar a que los servicios estén listos
log "Esperando a que los servicios estén listos..."
sleep 10

#-------------------------------------------------------------------------------
# 6. VERIFICACIÓN POST-DESPLIEGUE
#-------------------------------------------------------------------------------
log "${YELLOW}--- VERIFICANDO SERVICIOS ---${NC}"

SERVICES=("nestle_nginx_lb" "nestle_web_primary" "nestle_web_secondary" 
          "nestle_db_primary" "nestle_db_replica" "nestle_fileserver" 
          "nestle_ntp" "nestle_prometheus" "nestle_grafana")

for service in "${SERVICES[@]}"; do
    if docker ps --format "{{.Names}}" | grep -q "^${service}$"; then
        log "${GREEN}✓ $service: ACTIVO${NC}"
    else
        log "${RED}✗ $service: INACTIVO${NC}"
    fi
done

#-------------------------------------------------------------------------------
# 7. CONFIGURAR CRON JOBS
#-------------------------------------------------------------------------------
log "${YELLOW}--- CONFIGURANDO TAREAS AUTOMÁTICAS ---${NC}"

CRON_FILE="/tmp/nestle_cron"
cat > "$CRON_FILE" << EOF
# Backup diario a las 2:00 AM
0 2 * * * $PROJECT_DIR/scripts/backup_nestle.sh >> /var/log/nestle/cron_backup.log 2>&1

# Monitoreo cada 5 minutos
*/5 * * * * $PROJECT_DIR/scripts/monitor_nestle.sh >> /var/log/nestle/cron_monitor.log 2>&1

# Limpieza de logs semanal (domingos 3:00 AM)
0 3 * * 0 find /var/log/nestle -name "*.log" -mtime +30 -delete
EOF

crontab "$CRON_FILE" 2>/dev/null || sudo crontab "$CRON_FILE"
rm "$CRON_FILE"
log "${GREEN}✓ Tareas cron configuradas${NC}"

#-------------------------------------------------------------------------------
# 8. REPORTE FINAL
#-------------------------------------------------------------------------------
log "${CYAN}========================================${NC}"
log "${CYAN}  DESPLIEGUE COMPLETADO                 ${NC}"
log "${CYAN}========================================${NC}"
log "Servicios disponibles:"
log "  - Web:        http://localhost / https://localhost"
log "  - Grafana:    http://localhost:3000 (admin/nestle_grafana_2026)"
log "  - Prometheus: http://localhost:9090"
log "  - SSH:        localhost:2222"
log "  - MySQL:      localhost:3306"
log "  - Samba:      localhost:445"
log "${CYAN}========================================${NC}"

exit 0
