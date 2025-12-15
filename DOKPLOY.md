# 🚀 Deploy Rápido en Dokploy

¿Quieres deployar Fizzy en Dokploy? Sigue estos pasos:

## Inicio Rápido

1. **Genera tus secretos**:
   ```bash
   bash bin/generate-secrets
   ```

2. **Lee la guía completa**: [DOKPLOY_DEPLOY.md](DOKPLOY_DEPLOY.md)

3. **Configura en Dokploy**:
   - Crea un nuevo proyecto
   - Añade un servicio Compose apuntando a tu fork
   - Copia las variables de `.env.example` y completa con tus valores
   - Despliega

## Archivos Importantes

- [`docker-compose.yml`](docker-compose.yml) - Configuración de servicios
- [`.env.example`](.env.example) - Plantilla de variables de entorno
- [`DOKPLOY_DEPLOY.md`](DOKPLOY_DEPLOY.md) - Guía completa paso a paso
- [`db/init-databases.sql`](db/init-databases.sql) - Script de inicialización de BD

## Requisitos Mínimos

- Servidor con 2GB RAM y 20GB disco
- Docker instalado
- Dominio apuntando a tu servidor
- Credenciales SMTP (Gmail, SendGrid, Mailgun, etc.)

## ¿Necesitas Ayuda?

Lee la [guía completa de deployment](DOKPLOY_DEPLOY.md) que incluye:
- Configuración detallada
- Troubleshooting
- Consejos de seguridad
- Mantenimiento y backups

---

Para el deployment tradicional con Kamal, consulta el [README principal](README.md).
