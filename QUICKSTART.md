# 🚀 Quick Start - Deploy en 5 Minutos

## Para Solo Probar (Sin SMTP Real)

### 1. Copia las variables dummy
```bash
cp .env.testing .env
```

### 2. Edita SOLO este valor en `.env`:
```bash
APP_HOST=tu-dominio-en-dokploy.com
```

**Nota**: Ahora usa SQLite (más simple), ya no necesitas configurar MySQL.

### 3. En Dokploy:

#### Crear el Proyecto:
1. Click "Create Project" → Nombre: `fizzy`
2. Click "Add Service" → "Compose"
3. Nombre: `fizzy-app`

#### Configurar Git:
- Repository: `https://github.com/TU-USUARIO/fizzy.git`
- Branch: `main`
- Compose File: `docker-compose.yml`

#### Variables de Entorno:
Copia TODAS las líneas de tu archivo `.env` local a Dokploy:

**Mínimo necesario**:
```
APP_HOST=tu-dominio.com
SECRET_KEY_BASE=0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef
VAPID_PUBLIC_KEY=BNxDS7H-s3bPScDK0glRe7wyH0H0e9CqW5zvLCPsLM_ZGCwuXF8c3VJBcEGI5g4dKH8cEqnJX5jJQj2mz7lH8kQ
VAPID_PRIVATE_KEY=b_Xs8i7m5fZbxT7UlR2qN9kVwE5pQ3jL8mC6hF4tG2A
MAILER_FROM_ADDRESS=noreply@test.com
SMTP_ADDRESS=smtp.mailtrap.io
SMTP_PORT=2525
SMTP_DOMAIN=test.com
SMTP_USERNAME=dummy
SMTP_PASSWORD=dummy
SMTP_AUTHENTICATION=plain
SMTP_ENABLE_STARTTLS=true
```

#### Dominio:
1. Sección "Domains" → Agrega: `tu-dominio.com`
2. Habilita SSL

### 4. Deploy
Click "Deploy" y espera 5-10 minutos

### 5. Inicializar Base de Datos

Una vez desplegado, abre terminal en el contenedor `app`:

```bash
bin/rails db:migrate
```

### 6. ¡Listo! 🎉
Abre `https://tu-dominio.com`

---

## 🐛 Solución de Problemas Comunes

### "caching_sha2_password requires TLS"
- El `docker-compose.yml` ya tiene el fix
- Asegúrate de tener la última versión del repo
- Redeploya

### "port is already allocated"  
- Normal en Dokploy (usa Traefik)
- Verifica que `docker-compose.yml` use `expose:` no `ports:`

### "secret_key_base must be a type of String"
- Verifica que copiaste `SECRET_KEY_BASE` a las variables de entorno en Dokploy
- No debe estar vacía

---

## ⚠️ Limitaciones del Setup Dummy

- ❌ Los emails NO llegarán (magic links no funcionarán)
- ❌ Las notificaciones push usarán keys dummy
- ✅ La app cargará y funcionará visualmente
- ✅ Puedes probar la interfaz

## 📧 Para que funcione el login:

Necesitas SMTP real. Opciones gratis:

**Mailtrap (solo testing)**:
1. Registrate en https://mailtrap.io/
2. Copia las credenciales SMTP
3. Actualiza en Dokploy:
   - `SMTP_USERNAME=tu_username`
   - `SMTP_PASSWORD=tu_password`
4. Redeploya

**SendGrid (producción)**:
- https://sendgrid.com/ (100 emails/día gratis)

---

Para deployment completo ver: [DOKPLOY_DEPLOY.md](DOKPLOY_DEPLOY.md)
