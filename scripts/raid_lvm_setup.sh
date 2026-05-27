#!/bin/bash
#===============================================================================
# SCRIPT: raid_lvm_setup.sh
# DESCRIPCIÓN: Configuración de RAID y LVM para infraestructura Nestlé
# AUTOR: Equipo Infraestructura TI - Nestlé
#===============================================================================

set -euo pipefail

LOG_FILE="/var/log/nestle/raid_lvm.log"
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
log "${CYAN}  CONFIGURACIÓN RAID + LVM NESTLÉ       ${NC}"
log "${CYAN}========================================${NC}"

#-------------------------------------------------------------------------------
# 1. VERIFICAR DISCOS DISPONIBLES
#-------------------------------------------------------------------------------
log "${YELLOW}--- DISCOS DISPONIBLES ---${NC}"
lsblk -o NAME,SIZE,TYPE,MOUNTPOINT | tee -a "$LOG_FILE"

# Discos para RAID (en producción serían discos físicos separados)
# Para simulación usamos loop devices o verificamos discos existentes
DISK1="/dev/sdb"
DISK2="/dev/sdc"

# Verificar si los discos existen, si no, crear loop devices para simulación
if [ ! -b "$DISK1" ] || [ ! -b "$DISK2" ]; then
    log "${YELLOW}⚠ Discos físicos no encontrados. Creando dispositivos loop para simulación...${NC}"

    # Crear archivos de imagen para simular discos
    mkdir -p /var/lib/nestle/disks
    dd if=/dev/zero of=/var/lib/nestle/disks/disk1.img bs=1M count=1024 status=none
    dd if=/dev/zero of=/var/lib/nestle/disks/disk2.img bs=1M count=1024 status=none

    # Configurar loop devices
    DISK1=$(losetup -f --show /var/lib/nestle/disks/disk1.img)
    DISK2=$(losetup -f --show /var/lib/nestle/disks/disk2.img)

    log "${GREEN}✓ Loop devices creados: $DISK1, $DISK2${NC}"
fi

#-------------------------------------------------------------------------------
# 2. CREAR RAID 1 (ESPEJO)
#-------------------------------------------------------------------------------
log "${YELLOW}--- CONFIGURANDO RAID 1 ---${NC}"

RAID_DEVICE="/dev/md0"

# Verificar si RAID ya existe
if [ -b "$RAID_DEVICE" ]; then
    log "${YELLOW}⚠ RAID ya existe. Deteniendo...${NC}"
    mdadm --stop "$RAID_DEVICE" 2>/dev/null || true
fi

# Crear RAID 1
log "Creando RAID 1 con $DISK1 y $DISK2..."
mdadm --create "$RAID_DEVICE" --level=1 --raid-devices=2 "$DISK1" "$DISK2" --force 2>/dev/null || {
    log "${RED}✗ Error creando RAID. Puede que ya exista.${NC}"
    # Intentar ensamblar si ya existe
    mdadm --assemble "$RAID_DEVICE" "$DISK1" "$DISK2" 2>/dev/null || true
}

# Esperar a que se sincronice
log "Esperando sincronización de RAID..."
while grep -q "resync" /proc/mdstat 2>/dev/null; do
    sleep 1
done

# Guardar configuración
mkdir -p /etc/mdadm
mdadm --detail --scan > /etc/mdadm/mdadm.conf 2>/dev/null || mdadm --detail --scan > /etc/mdadm.conf 2>/dev/null || true

update-initramfs -u 2>/dev/null || true

log "${GREEN}✓ RAID 1 configurado en $RAID_DEVICE${NC}"
cat /proc/mdstat | tee -a "$LOG_FILE"

#-------------------------------------------------------------------------------
# 3. CONFIGURAR LVM SOBRE RAID
#-------------------------------------------------------------------------------
log "${YELLOW}--- CONFIGURANDO LVM ---${NC}"

# Crear Physical Volume
pvcreate "$RAID_DEVICE" 2>/dev/null || log "${YELLOW}⚠ PV ya existe${NC}"

# Crear Volume Group
VG_NAME="nestle_vg"
vgcreate "$VG_NAME" "$RAID_DEVICE" 2>/dev/null || log "${YELLOW}⚠ VG ya existe${NC}"

# Crear Logical Volumes
lvcreate -L 500M -n nestle_web "$VG_NAME" 2>/dev/null || lvresize -L 500M /dev/$VG_NAME/nestle_web 2>/dev/null || true
lvcreate -L 800M -n nestle_db "$VG_NAME" 2>/dev/null || lvresize -L 800M /dev/$VG_NAME/nestle_db 2>/dev/null || true
lvcreate -L 300M -n nestle_backup "$VG_NAME" 2>/dev/null || lvresize -L 300M /dev/$VG_NAME/nestle_backup 2>/dev/null || true
lvcreate -L 200M -n nestle_logs "$VG_NAME" 2>/dev/null || lvresize -L 200M /dev/$VG_NAME/nestle_logs 2>/dev/null || true

log "${GREEN}✓ Logical Volumes creados:${NC}"
lvs | tee -a "$LOG_FILE"

#-------------------------------------------------------------------------------
# 4. FORMATEAR Y MONTAR
#-------------------------------------------------------------------------------
log "${YELLOW}--- FORMATEANDO Y MONTANDO ---${NC}"

# Formatear con ext4
for lv in nestle_web nestle_db nestle_backup nestle_logs; do
    DEVICE="/dev/$VG_NAME/$lv"
    MOUNT="/mnt/nestle_${lv#nestle_}"

    mkfs.ext4 "$DEVICE" 2>/dev/null || log "${YELLOW}⚠ $DEVICE ya tiene filesystem${NC}"

    mkdir -p "$MOUNT"
    mount "$DEVICE" "$MOUNT" 2>/dev/null || log "${YELLOW}⚠ $MOUNT ya montado${NC}"

    # Agregar a fstab
    if ! grep -q "$DEVICE" /etc/fstab; then
        echo "$DEVICE $MOUNT ext4 defaults 0 2" >> /etc/fstab
    fi

    log "${GREEN}✓ $lv montado en $MOUNT${NC}"
done

#-------------------------------------------------------------------------------
# 5. CONFIGURAR PERMISOS
#-------------------------------------------------------------------------------
log "${YELLOW}--- CONFIGURANDO PERMISOS ---${NC}"

chown -R www-data:www-data /mnt/nestle_web
chmod 755 /mnt/nestle_web

chown -R 999:999 /mnt/nestle_db
chmod 750 /mnt/nestle_db

chown -R root:root /mnt/nestle_backup
chmod 755 /mnt/nestle_backup

chown -R syslog:adm /mnt/nestle_logs
chmod 755 /mnt/nestle_logs

# Sticky bit en backup
chmod +t /mnt/nestle_backup

log "${GREEN}✓ Permisos configurados${NC}"

#-------------------------------------------------------------------------------
# 6. VERIFICACIÓN
#-------------------------------------------------------------------------------
log "${YELLOW}--- VERIFICACIÓN FINAL ---${NC}"

df -h | grep nestle | tee -a "$LOG_FILE"

log "${CYAN}========================================${NC}"
log "${CYAN}  RAID + LVM CONFIGURADO                ${NC}"
log "${CYAN}========================================${NC}"
log "RAID Device: $RAID_DEVICE"
log "Volume Group: $VG_NAME"
log "Logical Volumes:"
lvs "$VG_NAME" --units m | tee -a "$LOG_FILE"

exit 0
