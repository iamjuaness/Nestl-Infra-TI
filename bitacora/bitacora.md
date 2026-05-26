# BITÁCORA DE PROYECTO - INFRAESTRUCTURA TI NESTLÉ

## Información General
- **Proyecto:** Infraestructura TI Nestlé
- **Fecha de inicio:** 2026-05-24
- **Responsables:** Juan Esteban Cardona, Juan Esteban Ramirezs

---

## Nota
Lamentablemente, nuestro equipo no pudo iniciar con mucho tiempo el proyecto, por cuestiones presentadas con otros proyectos de diferentes asignaturas y el trabajo de grado. Sin embargo, tratamos de llevarlo a cabo y además de cumplir con los requisitos del proyecto y la documentación técnica, fue importante para nosotros aprender y mejorar nuestra formación en la gestión de infraestructura.

## Registro de Actividades

### 2026-05-24 - Día 1: Planificación y Diseño
**Actividades realizadas:**
- [x] Análisis de requisitos del proyecto
- [x] Diseño de arquitectura de red
- [x] Definición de segmentación (VLANs/Subredes)
- [x] Asignación de direccionamiento IP
- [x] Selección de tecnologías (Docker, Apache, MySQL, etc.)

**Decisiones técnicas:**
- Uso de Docker Compose para orquestación
- Segmentación en 3 redes: Frontend, Backend, Management
- Balanceo de carga con Nginx
- Replicación MySQL Master-Slave

**Problemas encontrados:**
- Ninguno significativo

**Soluciones aplicadas:**
- N/A

---

### 2026-05-25 - Día 2: Implementación de Red y Docker
**Actividades realizadas:**
- [X] Configuración de red en Packet Tracer / GNS3
- [X] Creación de docker-compose.yml
- [X] Configuración de redes Docker (frontend, backend, management)
- [X] Pruebas de conectividad entre contenedores
- [X] Configuración de Apache/PHP
- [X] Configuración de MySQL Primary
- [X] Configuración de MySQL Replica
- [X] Pruebas de conexión web-db
- [X] Configuración de replicación
- [X] Configuración de Samba (archivos compartidos)
- [X] Configuración de NTP
- [X] Configuración de SSH Bastion
- [X] Pruebas de acceso a recursos compartidos
- [X] Configuración de Firewall (UFW/iptables)
- [X] Creación de usuarios y grupos
- [X] Configuración de permisos (SETUID, SETGID, Sticky Bit)
- [X] Configuración de SSL/TLS
- [X] Pruebas de penetración básicas
- [X] Simulación/Implementación de RAID
- [X] Configuración de LVM

**Decisiones técnicas:**
- Redes bridge con subnets definidas
- DNS interno con hostnames

---

### 2026-05-26 - Día 3: Servicios Web y Base de Datos
**Actividades realizadas:**
- [X] Configuración de volúmenes Docker
- [X] Pruebas de redundancia
- [X] Desarrollo de script de backup
- [X] Desarrollo de script de monitoreo
- [x] Desarrollo de script de despliegue
- [X] Configuración de cron jobs
- [X] Pruebas de automatización
- [X] Instalación de Prometheus
- [X] Instalación de Grafana
- [X] Configuración de dashboards
- [X] Configuración de alertas
- [X] Pruebas de monitoreo
- [X] Configuración de balanceo de carga
- [X] Pruebas de failover
- [X] Documentación de estrategias de recuperación
- [X] Simulación de fallos
- [X] Revisión de documento técnico
- [X] Pruebas finales de integración
- [X] Preparación de video demo
- [X] Preparación de sustentación
- [X] Creación de repositorio Git

**Decisiones técnicas:**
- Binlog formato ROW para replicación
- SSL obligatorio para conexiones MySQL

**Problemas encontrados:**
- Sin problemas

**Soluciones aplicadas:**
- N/A

---

## Lecciones Aprendidas

1. Apesar de no haber tenido problemas, el despliegue de la infraestructura se realizó con Docker Compose, lo cual no es lo más adecuado para producción. En el futuro, se debería utilizar Docker Swarm para escalabilidad.
2. Configurar un proyecto de infraestructura de TI es un desafío, pero es una tarea importante para la gestión de la infraestructura. La automatización de los procesos críticos, como la replicación de bases de datos y la monitorización, es fundamental para garantizar la disponibilidad y la seguridad de los servicios.
3. Es bueno trabajar en equipo y con las mejores herramientas disponibles, ya que al combinarlas se puede lograr cumplir con el proyecto de una manera más eficiente y segura.

---
