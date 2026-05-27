#!/bin/bash
#===============================================================================
# SCRIPT: backup_nestle.sh
# DESCRIPCIÓN: Backup automatizado de infraestructura Nestlé
# AUTOR: Equipo Infraestructura TI - Nestlé
# FECHA: 2026-05-24
#===============================================================================

set -euo pipefail

# Variables de configuración
BACKUP_DIR="/backup/nestle/$(date +%Y%m%d_%H%M%S)"
LOG_FILE="/var/log/nestle/backup.log"
RETENTION_DAYS=30
DB_CONTAINER="nestle_db_primary"
WEB_VOLUME="nestle_web_data"
DB_VOLUME="nestle_db_data"
DB_NAME="nestle_db"
DB_USER="root"
DB_PASS="nestle_root_2026"

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Función de logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Crear directorio de backup
mkdir -p "$BACKUP_DIR"/{db,web,configs,logs}

log "${YELLOW}Iniciando backup de infraestructura Nestlé...${NC}"

#-------------------------------------------------------------------------------
# 1. BACKUP DE BASE DE DATOS
#-------------------------------------------------------------------------------
log "${YELLOW}Realizando backup de MySQL...${NC}"
docker exec "$DB_CONTAINER" mysqldump -u "$DB_USER" -p"$DB_PASS" \
    --single-transaction \
    --routines \
    --triggers \
    --all-databases > "$BACKUP_DIR/db/full_backup.sql" 2>/dev/null

if [ $? -eq 0 ]; then
    gzip "$BACKUP_DIR/db/full_backup.sql"
    log "${GREEN}✓ Backup de base de datos completado${NC}"
else
    log "${RED}✗ Error en backup de base de datos${NC}"
    exit 1
fi

#-------------------------------------------------------------------------------
# 2. BACKUP DE ARCHIVOS WEB
#-------------------------------------------------------------------------------
log "${YELLOW}Realizando backup de archivos web...${NC}"
docker run --rm -v "$WEB_VOLUME":/source:ro -v "$BACKUP_DIR/web":/backup \
    alpine tar czf /backup/web_files.tar.gz -C /source . 2>/dev/null

if [ $? -eq 0 ]; then
    log "${GREEN}✓ Backup de archivos web completado${NC}"
else
    log "${RED}✗ Error en backup de archivos web${NC}"
fi

#-------------------------------------------------------------------------------
# 3. BACKUP DE CONFIGURACIONES
#-------------------------------------------------------------------------------
log "${YELLOW}Realizando backup de configuraciones...${NC}"
tar czf "$BACKUP_DIR/configs/docker_configs.tar.gz" -C / / configs/ 2>/dev/null || true
cp /docker-compose.yml "$BACKUP_DIR/configs/" 2>/dev/null || true
log "${GREEN}✓ Backup de configuraciones completado${NC}"

#-------------------------------------------------------------------------------
# 4. BACKUP DE LOGS
#-------------------------------------------------------------------------------
log "${YELLOW}Realizando backup de logs...${NC}"
docker logs "$DB_CONTAINER" > "$BACKUP_DIR/logs/db_container.log" 2>&1 || true
docker logs nestle_nginx_lb > "$BACKUP_DIR/logs/nginx_container.log" 2>&1 || true
journalctl -u docker --since "24 hours ago" > "$BACKUP_DIR/logs/docker_journal.log" 2>/dev/null || true
log "${GREEN}✓ Backup de logs completado${NC}"

#-------------------------------------------------------------------------------
# 5. GENERAR REPORTE
#-------------------------------------------------------------------------------
BACKUP_SIZE=$(du -sh "$BACKUP_DIR" | cut -f1)
cat > "$BACKUP_DIR/backup_report.txt" << EOF
=================================================================
REPORTE DE BACKUP - INFRAESTRUCTURA NESTLÉ
=================================================================
Fecha: $(date '+%Y-%m-%d %H:%M:%S')
Servidor: $(hostname)
Ubicación: $BACKUP_DIR
Tamaño Total: $BACKUP_SIZE

Contenido:
  - Base de datos: $BACKUP_DIR/db/full_backup.sql.gz
  - Archivos web: $BACKUP_DIR/web/web_files.tar.gz
  - Configuraciones: $BACKUP_DIR/configs/
  - Logs: $BACKUP_DIR/logs/

Estado: COMPLETADO EXITOSAMENTE
=================================================================
EOF

log "${GREEN}✓ Backup finalizado. Tamaño: $BACKUP_SIZE${NC}"

#-------------------------------------------------------------------------------
# 6. LIMPIEZA DE BACKUPS ANTIGUOS
#-------------------------------------------------------------------------------
log "${YELLOW}Limpiando backups antiguos (>$RETENTION_DAYS días)...${NC}"
find /backup/nestle -maxdepth 1 -type d -mtime +$RETENTION_DAYS -exec rm -rf {} + 2>/dev/null || true
log "${GREEN}✓ Limpieza completada${NC}"

#-------------------------------------------------------------------------------
# 7. VERIFICACIÓN DE INTEGRIDAD
#-------------------------------------------------------------------------------
log "${YELLOW}Verificando integridad del backup...${NC}"
if [ -f "$BACKUP_DIR/db/full_backup.sql.gz" ]; then
    gunzip -t "$BACKUP_DIR/db/full_backup.sql.gz" 2>/dev/null
    if [ $? -eq 0 ]; then
        log "${GREEN}✓ Integridad del backup verificada${NC}"
    else
        log "${RED}✗ Error de integridad en el backup${NC}"
    fi
fi

log "${GREEN}========================================${NC}"
log "${GREEN}BACKUP COMPLETADO: $BACKUP_DIR${NC}"
log "${GREEN}========================================${NC}"

exit 0
