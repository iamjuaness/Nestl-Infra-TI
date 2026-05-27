# 🏭 Infraestructura TI - Nestlé

> Proyecto Final: Administración de Infraestructura TI

## 📋 Descripción

Infraestructura TI completa, segura y escalable para Nestlé, implementada con Docker Compose. Incluye servicios web con alta disponibilidad, base de datos con replicación, monitoreo en tiempo real, automatización de backups y seguridad por capas.

## 🚀 Inicio Rápido

### Requisitos
- Docker 20.10+
- Docker Compose 2.0+
- 4GB RAM mínimo
- 20GB disco disponible

### Despliegue

```bash
# 1. Clonar repositorio
git clone https://github.com/tu-usuario/nestle-infra.git
cd nestle-infra

# 2. Ejecutar despliegue automatizado
chmod +x scripts/*.sh
sudo ./scripts/deploy_nestle.sh production

# 3. Verificar servicios
docker-compose -f /docker-compose.yml ps
```

### Acceso a Servicios

| Servicio | URL | Credenciales |
|----------|-----|-------------|
| Web | https://localhost | - |
| Grafana | http://localhost:3000 | admin / nestle_grafana_2026 |
| Prometheus | http://localhost:9090 | - |
| MySQL | localhost:3306 | root / nestle_root_2026 |
| SSH | localhost:2222 | Clave pública |

## 📁 Estructura del Proyecto

```
nestle_infra_ti/
├── /
│   ├── docker-compose.yml      # Orquestación de servicios
│   └── Dockerfile.apache       # Imagen personalizada Apache
├── configs/
│   ├── apache/                 # Configuración virtualhost
│   ├── mysql/                  # Configuración MySQL (primary/replica)
│   ├── nginx/                  # Load balancer + SSL
│   ├── samba/                  # Compartición de archivos
│   ├── ssh/                    # Claves autorizadas
│   ├── prometheus/             # Métricas y targets
│   └── grafana/                # Dashboards y datasources
├── scripts/
│   ├── deploy_nestle.sh        # Despliegue completo
│   ├── backup_nestle.sh        # Backup automatizado
│   └── monitor_nestle.sh       # Monitoreo de salud
├── docs/
│   └── documento_tecnico.md    # Documentación completa
├── bitacora/
│   └── bitacora.md             # Registro de actividades
└── README.md                   # Este archivo
```

## 🔒 Seguridad

- **Firewall:** UFW/iptables con política DENY por defecto
- **SSL/TLS:** Certificados para todas las conexiones HTTPS
- **Permisos especiales:** SETUID, SETGID, Sticky Bit configurados
- **Segmentación:** 3 redes Docker aisladas
- **SSH:** Acceso solo por clave pública, bastion host

## 📊 Monitoreo

- **Prometheus:** Métricas de contenedores y sistema
- **Grafana:** Dashboards visuales
- **Scripts:** Monitoreo cada 5 minutos vía cron

## 💾 Backup

- **Automático:** Diario a las 2:00 AM
- **Retención:** 30 días
- **Contenido:** Base de datos, archivos web, configuraciones, logs

## 🔄 Alta Disponibilidad

- Balanceo de carga Nginx (least_conn)
- Replicación MySQL Master-Slave
- Healthchecks en todos los contenedores
- Auto-restart de servicios caídos

## 🛠️ Comandos Útiles

```bash
# Escalar servicios web
docker-compose -f /docker-compose.yml up -d --scale web_primary=3

# Ver logs en tiempo real
docker-compose -f /docker-compose.yml logs -f

# Backup manual
./scripts/backup_nestle.sh

# Monitoreo manual
./scripts/monitor_nestle.sh

# Acceso a base de datos
docker exec -it nestle_db_primary mysql -u root -p

# Ver métricas Prometheus
curl http://localhost:9090/api/v1/status/targets
```

## 📚 Documentación

- [Documento Técnico Completo](docs/documento_tecnico.md)
- [Bitácora del Proyecto](bitacora/bitacora.md)

## 👥 Autores

- Juan Esteban Cardona
- Juan Esteban Ramirez

## 📄 Licencia

Proyecto académico - Universidad del Quindío

