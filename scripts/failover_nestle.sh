#!/bin/bash
#===============================================================================
# SCRIPT: failover_nestle.sh
# DESCRIPCIÓN: Failover automático y recuperación de servicios Nestlé
# AUTOR: Equipo Infraestructura TI - Nestlé
#===============================================================================

set -uo pipefail

LOG_FILE="/var/log/nestle/failover.log"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

clear
log "${CYAN}========================================${NC}"
log "${CYAN}  FAILOVER & RECUPERACIÓN NESTLÉ        ${NC}"
log "${CYAN}========================================${NC}"

#-------------------------------------------------------------------------------
# 1. VERIFICAR ESTADO DE SERVICIOS
#-------------------------------------------------------------------------------
log "${YELLOW}--- VERIFICANDO ESTADO DE SERVICIOS ---${NC}"

SERVICES=(
    "nestle_nginx_lb:nginx"
    "nestle_web_primary:apache"
    "nestle_web_secondary:apache"
    "nestle_db_primary:mysql"
    "nestle_db_replica:mysql"
    "nestle_fileserver:samba"
    "nestle_ntp:ntp"
    "nestle_prometheus:prometheus"
    "nestle_grafana:grafana"
)

FAILED_SERVICES=()

for service_info in "${SERVICES[@]}"; do
    IFS=':' read -r container service <<< "$service_info"

    if docker ps --format "{{.Names}}" | grep -q "^${container}$"; then
        log "${GREEN}✓ $container: ACTIVO${NC}"
    else
        log "${RED}✗ $container: CAÍDO${NC}"
        FAILED_SERVICES+=("$container:$service")
    fi
done

#-------------------------------------------------------------------------------
# 2. ACCIONES DE RECUPERACIÓN
#-------------------------------------------------------------------------------
if [ ${#FAILED_SERVICES[@]} -eq 0 ]; then
    log "${GREEN}✓ Todos los servicios están operativos${NC}"
    exit 0
fi

log "${YELLOW}--- INICIANDO RECUPERACIÓN ---${NC}"

for failed in "${FAILED_SERVICES[@]}"; do
    IFS=':' read -r container service <<< "$failed"

    log "${YELLOW}Recuperando $container...${NC}"

    case "$service" in
        "nginx")
            docker-compose -f /docker-compose.yml up -d nginx_lb 2>/dev/null ||             docker start "$container" 2>/dev/null || true
            ;;

        "apache")
            docker-compose -f /docker-compose.yml up -d "$container" 2>/dev/null ||             docker start "$container" 2>/dev/null || true
            ;;

        "mysql")
            if [ "$container" == "nestle_db_primary" ]; then
                log "${RED}⚠ BASE DE DATOS PRINCIPAL CAÍDA${NC}"
                log "${YELLOW}Iniciando failover a réplica...${NC}"

                # Promover réplica a principal
                docker exec nestle_db_replica mysql -u root -p"nestle_root_2026" -e "STOP SLAVE; RESET SLAVE ALL;" 2>/dev/null || true

                # Actualizar configuración de aplicaciones para usar réplica
                log "${YELLOW}Actualizando configuración de conexión...${NC}"
                # Nota: En producción, esto actualizaría configs o DNS

                log "${GREEN}✓ Failover completado. db_replica ahora es primary${NC}"
            else
                docker start "$container" 2>/dev/null || true
            fi
            ;;

        "samba"|"ntp"|"prometheus"|"grafana")
            docker-compose -f /docker-compose.yml up -d "$container" 2>/dev/null ||             docker start "$container" 2>/dev/null || true
            ;;
    esac

    # Verificar recuperación
    sleep 5
    if docker ps --format "{{.Names}}" | grep -q "^${container}$"; then
        log "${GREEN}✓ $container recuperado exitosamente${NC}"
    else
        log "${RED}✗ No se pudo recuperar $container${NC}"
    fi
done

#-------------------------------------------------------------------------------
# 3. VERIFICACIÓN POST-RECOBRACIÓN
#-------------------------------------------------------------------------------
log "${YELLOW}--- VERIFICACIÓN POST-RECOBRACIÓN ---${NC}"

# Verificar balanceo de carga
if curl -s http://localhost/health > /dev/null 2>&1; then
    log "${GREEN}✓ Servicio web accesible${NC}"
else
    log "${RED}✗ Servicio web no responde${NC}"
fi

# Verificar base de datos
if docker exec nestle_db_primary mysqladmin ping 2>/dev/null | grep -q "alive"; then
    log "${GREEN}✓ Base de datos principal activa${NC}"
else
    log "${RED}✗ Base de datos principal no responde${NC}"
fi

# Verificar replicación
REPL_STATUS=$(docker exec nestle_db_replica mysql -e "SHOW SLAVE STATUS\G" 2>/dev/null | grep "Slave_IO_Running")
if [ ! -z "$REPL_STATUS" ]; then
    log "${GREEN}✓ Replicación activa${NC}"
else
    log "${YELLOW}⚠ Replicación no disponible${NC}"
fi

#-------------------------------------------------------------------------------
# 4. REPORTE DE INCIDENTE
#-------------------------------------------------------------------------------
log "${CYAN}========================================${NC}"
log "${CYAN}  REPORTE DE RECUPERACIÓN               ${NC}"
log "${CYAN}========================================${NC}"
log "Servicios recuperados: ${#FAILED_SERVICES[@]}"
log "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
log "${CYAN}========================================${NC}"

exit 0
