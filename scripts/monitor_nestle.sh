#!/bin/bash
#===============================================================================
# SCRIPT: monitor_nestle.sh
# DESCRIPCIÓN: Monitoreo básico de infraestructura Nestlé
# AUTOR: Equipo Infraestructura TI - Nestlé
#===============================================================================

set -uo pipefail

LOG_FILE="/var/log/nestle/monitor.log"
ALERT_FILE="/var/log/nestle/alerts.log"
THRESHOLD_CPU=80
THRESHOLD_MEM=85
THRESHOLD_DISK=90

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

alert() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ALERTA: $1" | tee -a "$ALERT_FILE"
}

clear
log "${CYAN}========================================${NC}"
log "${CYAN}  MONITOREO INFRAESTRUCTURA NESTLÉ      ${NC}"
log "${CYAN}========================================${NC}"

#-------------------------------------------------------------------------------
# 1. ESTADO DE CONTENEDORES DOCKER
#-------------------------------------------------------------------------------
log "${YELLOW}--- ESTADO DE CONTENEDORES ---${NC}"
CONTAINERS=$(docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null)
if [ $? -eq 0 ]; then
    echo "$CONTAINERS" | while read line; do
        log "$line"
    done

    # Verificar contenedores caídos
    DOWN_CONTAINERS=$(docker ps -f "status=exited" --format "{{.Names}}" 2>/dev/null)
    if [ ! -z "$DOWN_CONTAINERS" ]; then
        alert "Contenedores caídos detectados: $DOWN_CONTAINERS"
    fi
else
    alert "Docker no está disponible"
fi

#-------------------------------------------------------------------------------
# 2. USO DE RECURSOS DEL SISTEMA
#-------------------------------------------------------------------------------
log "${YELLOW}--- USO DE RECURSOS DEL SISTEMA ---${NC}"

# CPU
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
CPU_INT=${CPU_USAGE%.*}
log "CPU Usage: ${CPU_USAGE}%"
if (( $(echo "$CPU_INT > $THRESHOLD_CPU" | bc -l) )); then
    alert "Uso de CPU crítico: ${CPU_USAGE}%"
fi

# Memoria
MEM_INFO=$(free | grep Mem)
MEM_TOTAL=$(echo $MEM_INFO | awk '{print $2}')
MEM_USED=$(echo $MEM_INFO | awk '{print $3}')
MEM_USAGE=$(echo "scale=2; ($MEM_USED / $MEM_TOTAL) * 100" | bc)
MEM_INT=${MEM_USAGE%.*}
log "Memoria Usage: ${MEM_USAGE}% (${MEM_USED}/${MEM_TOTAL} KB)"
if (( $(echo "$MEM_INT > $THRESHOLD_MEM" | bc -l) )); then
    alert "Uso de Memoria crítico: ${MEM_USAGE}%"
fi

# Disco
DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
log "Disco Root Usage: ${DISK_USAGE}%"
if [ "$DISK_USAGE" -gt "$THRESHOLD_DISK" ]; then
    alert "Uso de Disco crítico: ${DISK_USAGE}%"
fi

#-------------------------------------------------------------------------------
# 3. ESTADO DE SERVICIOS CLAVE
#-------------------------------------------------------------------------------
log "${YELLOW}--- ESTADO DE SERVICIOS ---${NC}"

# Verificar servicios web
for port in 80 443 3306; do
    if nc -z localhost $port 2>/dev/null; then
        log "${GREEN}✓ Puerto $port: ACTIVO${NC}"
    else
        alert "Puerto $port: INACTIVO"
    fi
done

#-------------------------------------------------------------------------------
# 4. ESTADO DE RED
#-------------------------------------------------------------------------------
log "${YELLOW}--- ESTADO DE RED ---${NC}"
IP_ADDR=$(hostname -I | awk '{print $1}')
log "IP del servidor: $IP_ADDR"

# Interfaces de red
ip -brief addr show 2>/dev/null | while read line; do
    log "Interfaz: $line"
done

# Conexiones activas
ACTIVE_CONN=$(netstat -an 2>/dev/null | grep ESTABLISHED | wc -l)
log "Conexiones activas: $ACTIVE_CONN"

#-------------------------------------------------------------------------------
# 5. ESTADO DE BASE DE DATOS
#-------------------------------------------------------------------------------
log "${YELLOW}--- ESTADO DE BASE DE DATOS ---${NC}"
DB_STATUS=$(docker exec nestle_db_primary mysqladmin ping 2>/dev/null)
if [ "$DB_STATUS" == "mysqld is alive" ]; then
    log "${GREEN}✓ MySQL Primary: ACTIVO${NC}"
else
    alert "MySQL Primary: INACTIVO"
fi

# Replicación
REPL_STATUS=$(docker exec nestle_db_replica mysql -e "SHOW SLAVE STATUS\G" 2>/dev/null | grep "Slave_IO_Running\|Slave_SQL_Running")
if [ ! -z "$REPL_STATUS" ]; then
    log "Estado de replicación:"
    echo "$REPL_STATUS" | while read line; do
        log "  $line"
    done
else
    log "${YELLOW}⚠ Replicación no configurada o contenedor no disponible${NC}"
fi

#-------------------------------------------------------------------------------
# 6. LOGS RECIENTES
#-------------------------------------------------------------------------------
log "${YELLOW}--- LOGS RECIENTES (últimos 10 errores) ---${NC}"
journalctl -p err --since "1 hour ago" --no-pager 2>/dev/null | tail -10 | while read line; do
    log "$line"
done

#-------------------------------------------------------------------------------
# 7. REPORTE FINAL
#-------------------------------------------------------------------------------
log "${CYAN}========================================${NC}"
log "${CYAN}  MONITOREO COMPLETADO                  ${NC}"
log "${CYAN}========================================${NC}"

# Guardar métricas para Prometheus (si aplica)
METRICS_FILE="/var/lib/node_exporter/textfile_collector/nestle_metrics.prom"
mkdir -p "$(dirname $METRICS_FILE)" 2>/dev/null || true
cat > "$METRICS_FILE" << EOF
# HELP nestle_cpu_usage_percent Uso de CPU
# TYPE nestle_cpu_usage_percent gauge
nestle_cpu_usage_percent $CPU_USAGE

# HELP nestle_memory_usage_percent Uso de Memoria
# TYPE nestle_memory_usage_percent gauge
nestle_memory_usage_percent $MEM_USAGE

# HELP nestle_disk_usage_percent Uso de Disco
# TYPE nestle_disk_usage_percent gauge
nestle_disk_usage_percent $DISK_USAGE
EOF

exit 0
