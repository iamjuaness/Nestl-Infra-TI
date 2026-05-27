# 🚀 GUÍA RÁPIDA - INFRAESTRUCTURA NESTLÉ

## Pasos para ejecutar el proyecto desde cero

### Paso 1: Preparar el entorno
```bash
# Actualizar sistema
sudo apt update && sudo apt upgrade -y

# Instalar dependencias
sudo apt install -y docker.io docker-compose git curl wget openssl

# Agregar usuario al grupo docker
sudo usermod -aG docker $USER
newgrp docker
```

### Paso 2: Clonar/Descargar el proyecto
```bash
# Si usas Git
git init
git add .
git commit -m "Initial commit: Infraestructura Nestlé"

# O simplemente copia la carpeta nestle_infra_ti a tu máquina
cd nestle_infra_ti
```

### Paso 3: Ejecutar el despliegue (TODO SE CONFIGURA AUTOMÁTICAMENTE)
```bash
# Dar permisos a los scripts
chmod +x scripts/*.sh

# Ejecutar despliegue completo
sudo ./scripts/deploy_nestle.sh production
```

Este script hará:
- ✅ Verificar requisitos (Docker, Docker Compose)
- ✅ Crear usuarios del sistema (nestle_admin, nestle_user)
- ✅ Configurar firewall (UFW/iptables)
- ✅ Generar certificados SSL
- ✅ Construir imágenes Docker
- ✅ Levantar TODOS los servicios
- ✅ Configurar cron jobs (backup + monitoreo)

### Paso 4: Configurar RAID y LVM (opcional - para demostración)
```bash
sudo ./scripts/raid_lvm_setup.sh
```

### Paso 5: Configurar replicación MySQL
```bash
./scripts/setup_mysql_replication.sh
```

### Paso 6: Verificar que todo funciona
```bash
# Ver servicios corriendo
docker-compose -f /docker-compose.yml ps

# Ver logs
docker-compose -f /docker-compose.yml logs -f

# Probar web
curl http://localhost
curl https://localhost

# Probar base de datos
docker exec -it nestle_db_primary mysql -u root -p
# Password: nestle_root_2026

# Probar monitoreo
# Abrir navegador: http://localhost:9090 (Prometheus)
# Abrir navegador: http://localhost:3000 (Grafana)
#   User: admin
#   Pass: nestle_grafana_2026
```

### Paso 7: Ejecutar scripts de automatización
```bash
# Backup manual
./scripts/backup_nestle.sh

# Monitoreo manual
./scripts/monitor_nestle.sh

# Verificar failover
./scripts/failover_nestle.sh
```

---

## 🔧 Comandos útiles

```bash
# Detener todos los servicios
docker-compose -f /docker-compose.yml down

# Reiniciar un servicio específico
docker-compose -f /docker-compose.yml restart web_primary

# Escalar servicios web (alta disponibilidad)
docker-compose -f /docker-compose.yml up -d --scale web_primary=3

# Ver logs de un servicio específico
docker logs -f nestle_db_primary

# Entrar a un contenedor
docker exec -it nestle_web_primary bash

# Ver uso de recursos
docker stats

# Ver redes Docker
docker network ls
docker network inspect docker_frontend
```

---

## ⚠️ Solución de problemas comunes

### "Docker no está instalado"
```bash
sudo apt install docker.io docker-compose
sudo systemctl enable docker
sudo systemctl start docker
```

### "Puerto ya en uso"
```bash
# Ver qué proceso usa el puerto
sudo lsof -i :80
sudo lsof -i :3306

# Matar proceso o cambiar puerto en docker-compose.yml
```

### "Permiso denegado en scripts"
```bash
chmod +x scripts/*.sh
```

### "Contenedor no inicia"
```bash
# Ver logs
docker logs nestle_db_primary

# Verificar configuración
docker-compose -f /docker-compose.yml config
```

---

*Para cualquier duda, revisar el documento técnico en `docs/documento_tecnico.md`*
