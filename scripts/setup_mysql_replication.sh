#!/bin/bash
#===============================================================================
# SCRIPT: setup_mysql_replication.sh
# DESCRIPCIÓN: Configura replicación Master-Slave en MySQL Nestlé
# AUTOR: Equipo Infraestructura TI - Nestlé
#===============================================================================

set -euo pipefail

LOG_FILE="/var/log/nestle/replication.log"
mkdir -p "$(dirname "$LOG_FILE")"
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
log "${CYAN}  CONFIGURACIÓN REPLICACIÓN MYSQL       ${NC}"
log "${CYAN}========================================${NC}"

MASTER_CONTAINER="nestle_db_primary"
SLAVE_CONTAINER="nestle_db_replica"
REPL_USER="repl_user"
REPL_PASS="repl_secure_2026"
ROOT_PASS="nestle_root_2026"

#-------------------------------------------------------------------------------
# 1. VERIFICAR CONTENEDORES
#-------------------------------------------------------------------------------
log "${YELLOW}--- VERIFICANDO CONTENEDORES ---${NC}"

for container in "$MASTER_CONTAINER" "$SLAVE_CONTAINER"; do
    if ! docker ps --format "{{.Names}}" | grep -q "^${container}$"; then
        log "${RED}✗ Contenedor $container no está corriendo${NC}"
        exit 1
    fi
    log "${GREEN}✓ $container: ACTIVO${NC}"
done

#-------------------------------------------------------------------------------
# 2. CONFIGURAR MASTER
#-------------------------------------------------------------------------------
log "${YELLOW}--- CONFIGURANDO MASTER ---${NC}"

# Crear usuario de replicación (si no existe)
docker exec "$MASTER_CONTAINER" mysql -u root -p"$ROOT_PASS" -e "
CREATE USER IF NOT EXISTS '$REPL_USER'@'%' IDENTIFIED BY '$REPL_PASS';
GRANT REPLICATION SLAVE ON *.* TO '$REPL_USER'@'%';
FLUSH PRIVILEGES;
" 2>/dev/null

# Obtener posición del binlog
MASTER_STATUS=$(docker exec "$MASTER_CONTAINER" mysql -u root -p"$ROOT_PASS" -e "SHOW MASTER STATUS\G" 2>/dev/null)
BINLOG_FILE=$(echo "$MASTER_STATUS" | grep "File:" | awk '{print $2}')
BINLOG_POS=$(echo "$MASTER_STATUS" | grep "Position:" | awk '{print $2}')

log "${GREEN}✓ Master configurado${NC}"
log "  Binlog File: $BINLOG_FILE"
log "  Position: $BINLOG_POS"

#-------------------------------------------------------------------------------
# 3. CONFIGURAR SLAVE
#-------------------------------------------------------------------------------
log "${YELLOW}--- CONFIGURANDO SLAVE ---${NC}"

# Detener slave si está corriendo
docker exec "$SLAVE_CONTAINER" mysql -u root -p"$ROOT_PASS" -e "STOP SLAVE;" 2>/dev/null || true

# Configurar master
docker exec "$SLAVE_CONTAINER" mysql -u root -p"$ROOT_PASS" -e "
CHANGE MASTER TO
    MASTER_HOST='$MASTER_CONTAINER',
    MASTER_USER='$REPL_USER',
    MASTER_PASSWORD='$REPL_PASS',
    MASTER_LOG_FILE='$BINLOG_FILE',
    MASTER_LOG_POS=$BINLOG_POS,
    MASTER_CONNECT_RETRY=10;
" 2>/dev/null

# Iniciar slave
docker exec "$SLAVE_CONTAINER" mysql -u root -p"$ROOT_PASS" -e "START SLAVE;" 2>/dev/null

log "${GREEN}✓ Slave configurado${NC}"

#-------------------------------------------------------------------------------
# 4. VERIFICAR REPLICACIÓN
#-------------------------------------------------------------------------------
log "${YELLOW}--- VERIFICANDO REPLICACIÓN ---${NC}"

sleep 3

SLAVE_STATUS=$(docker exec "$SLAVE_CONTAINER" mysql -u root -p"$ROOT_PASS" -e "SHOW SLAVE STATUS\G" 2>/dev/null)

IO_RUNNING=$(echo "$SLAVE_STATUS" | grep "Slave_IO_Running" | awk '{print $2}')
SQL_RUNNING=$(echo "$SLAVE_STATUS" | grep "Slave_SQL_Running" | awk '{print $2}')

if [ "$IO_RUNNING" == "Yes" ] && [ "$SQL_RUNNING" == "Yes" ]; then
    log "${GREEN}✓ Replicación activa y funcionando${NC}"
    log "  IO Thread: $IO_RUNNING"
    log "  SQL Thread: $SQL_RUNNING"
else
    log "${RED}✗ Problema en replicación${NC}"
    log "  IO Thread: $IO_RUNNING"
    log "  SQL Thread: $SQL_RUNNING"
    log "${YELLOW}Verificando errores...${NC}"
    echo "$SLAVE_STATUS" | grep "Last_Error" | tee -a "$LOG_FILE"
fi

#-------------------------------------------------------------------------------
# 5. PRUEBA DE REPLICACIÓN
#-------------------------------------------------------------------------------
log "${YELLOW}--- PRUEBA DE REPLICACIÓN ---${NC}"

# Insertar dato de prueba en master
docker exec "$MASTER_CONTAINER" mysql -u root -p"$ROOT_PASS" -e "
USE nestle_db;
INSERT INTO system_logs (servicio, nivel, mensaje) 
VALUES ('replication', 'INFO', 'Prueba de replicación - $(date)');
" 2>/dev/null

sleep 2

# Verificar en slave
SLAVE_COUNT=$(docker exec "$SLAVE_CONTAINER" mysql -u root -p"$ROOT_PASS" -e "
USE nestle_db;
SELECT COUNT(*) FROM system_logs WHERE servicio='replication';
" 2>/dev/null | tail -1)

if [ "$SLAVE_COUNT" -gt 0 ]; then
    log "${GREEN}✓ Prueba de replicación exitosa ($SLAVE_COUNT registros)${NC}"
else
    log "${RED}✗ Prueba de replicación fallida${NC}"
fi

log "${CYAN}========================================${NC}"
log "${CYAN}  REPLICACIÓN CONFIGURADA               ${NC}"
log "${CYAN}========================================${NC}"

exit 0
