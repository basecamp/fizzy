# 🚀 Guía de Deployment de Fizzy en Dokploy

Esta guía te llevará paso a paso para deployar Fizzy en tu propia instancia de Dokploy.

## 📋 Requisitos Previos

1. Una instancia de **Dokploy** funcionando
2. Un servidor con **Docker** instalado
3. Un **dominio** apuntando a tu servidor
4. Credenciales de un proveedor **SMTP** para enviar emails

## 🎯 Paso 1: Preparar tu Fork del Repositorio

1. **Haz un fork** de este repositorio en tu cuenta de GitHub

2. **Clona tu fork** en tu máquina local:
   ```bash
   git clone https://github.com/TU-USUARIO/fizzy.git
   cd fizzy
   ```

## 🔑 Paso 2: Generar las Llaves y Secretos Necesarios

### 2.1 Generar SECRET_KEY_BASE

Ejecuta este comando para generar una llave secreta:

```bash
openssl rand -hex 64
```

Guarda el resultado, lo necesitarás más adelante.

### 2.2 Generar VAPID Keys (para notificaciones push)

Las llaves VAPID son necesarias para las notificaciones del navegador. Genera un par de llaves ejecutando:

```bash
docker run --rm -it ruby:3.4.7-slim bash -c "
  gem install webpush && 
  ruby -e \"
    require 'webpush'
    vapid_key = Webpush.generate_key
    puts 'VAPID_PUBLIC_KEY=' + vapid_key.public_key
    puts 'VAPID_PRIVATE_KEY=' + vapid_key.private_key
  \"
"
```

O si prefieres hacerlo desde Rails en desarrollo local:

```bash
bin/rails console
```

Luego ejecuta en la consola:

```ruby
vapid_key = WebPush.generate_key
puts "VAPID_PUBLIC_KEY=#{vapid_key.public_key}"
puts "VAPID_PRIVATE_KEY=#{vapid_key.private_key}"
```

Guarda ambas llaves (pública y privada).

### 2.3 Configurar SMTP

Necesitas credenciales de un proveedor SMTP. Algunas opciones recomendadas:

#### **Gmail** (solo para pruebas o bajo volumen)
- SMTP_ADDRESS: `smtp.gmail.com`
- SMTP_PORT: `587`
- Necesitas crear una "App Password" si tienes 2FA: https://support.google.com/accounts/answer/185833

#### **SendGrid** (recomendado para producción)
- SMTP_ADDRESS: `smtp.sendgrid.net`
- SMTP_PORT: `587`
- SMTP_USERNAME: `apikey`
- SMTP_PASSWORD: Tu API Key de SendGrid
- Registro gratuito: https://sendgrid.com/

#### **Mailgun** (recomendado para producción)
- SMTP_ADDRESS: `smtp.mailgun.org`
- SMTP_PORT: `587`
- Obtén credenciales en: https://www.mailgun.com/

#### **Amazon SES** (para alto volumen)
- SMTP_ADDRESS: `email-smtp.us-east-1.amazonaws.com` (cambia la región)
- SMTP_PORT: `587`
- Genera credenciales SMTP en la consola de AWS SES

## 📝 Paso 3: Configurar Variables de Entorno

### Opción A: Testing Rápido (valores dummy)

Si solo quieres **probar** que funciona sin configurar todo:

1. **Copia el archivo de testing**:
   ```bash
   cp .env.testing .env
   ```

2. **Edita solo estos valores**:
   ```bash
   nano .env
   ```
   
   Cambia únicamente:
   - `APP_HOST=fizzy.tudominio.com` → Tu dominio real en Dokploy
   - `MYSQL_ROOT_PASSWORD` → Una contraseña diferente (cualquiera)

3. **Listo** - Ya puedes deployar. Los emails no funcionarán pero la app sí.

### Opción B: Configuración Completa (producción)

Si quieres una instalación completa y funcional:

1. **Copia el archivo de ejemplo**:
   ```bash
   cp .env.example .env
   ```

2. **Edita el archivo `.env`** con tus valores:

   ```bash
   nano .env  # o usa tu editor preferido
   ```

3. **Completa TODOS los valores**. Aquí un ejemplo:

   ```env
   # URL de tu aplicación
   APP_HOST=fizzy.tudominio.com
   
   # Rails secret (generada en paso 2.1)
   SECRET_KEY_BASE=tu_secret_key_base_de_64_caracteres...
   
   # VAPID keys (generadas en paso 2.2)
   VAPID_PUBLIC_KEY=BG8x...
   VAPID_PRIVATE_KEY=abc123...
   
   # Email configuration
   MAILER_FROM_ADDRESS=noreply@tudominio.com
   SMTP_ADDRESS=smtp.sendgrid.net
   SMTP_PORT=587
   SMTP_DOMAIN=tudominio.com
   SMTP_USERNAME=apikey
   SMTP_PASSWORD=SG.tu_api_key_aqui
   SMTP_AUTHENTICATION=plain
   SMTP_ENABLE_STARTTLS=true
   ```

4. **IMPORTANTE**: NO commits el archivo `.env` a tu repositorio. Ya está en `.gitignore`.

## 🔧 Paso 4: Actualizar Configuración de Producción

Edita el archivo `config/environments/production.rb` para configurar tu SMTP. Descomenta y modifica las líneas 9-17:

```ruby
config.action_mailer.smtp_settings = {
  address:              ENV['SMTP_ADDRESS'],
  port:                 ENV['SMTP_PORT'],
  domain:               ENV['SMTP_DOMAIN'],
  user_name:            ENV['SMTP_USERNAME'],
  password:             ENV['SMTP_PASSWORD'],
  authentication:       ENV['SMTP_AUTHENTICATION']&.to_sym || :plain,
  enable_starttls_auto: ENV['SMTP_ENABLE_STARTTLS'] == 'true'
}
```

Guarda los cambios y haz commit:

```bash
git add config/environments/production.rb
git commit -m "Configure SMTP settings for production"
git push origin main
```

## 🐳 Paso 5: Configurar en Dokploy

### 5.1 Crear Nuevo Proyecto

1. Accede a tu dashboard de Dokploy
2. Click en **"Create Project"** o **"Nuevo Proyecto"**
3. Dale un nombre descriptivo, por ejemplo: `fizzy-production`

### 5.2 Crear Servicio Compose

1. Dentro del proyecto, click en **"Add Service"** → **"Compose"**
2. Dale un nombre: `fizzy`
3. En **"Repository"**:
   - Selecciona **Git** como fuente
   - Pega la URL de tu fork: `https://github.com/TU-USUARIO/fizzy.git`
   - Branch: `main`
4. En **"Compose File"**: Deja el valor por defecto `docker-compose.yml`

### 5.3 Configurar Variables de Entorno

En la sección **"Environment"** o **"Variables de Entorno"** de Dokploy:

1. Click en **"Add Variable"** para cada variable
2. Copia **TODAS** las variables de tu archivo `.env` local
3. **MUY IMPORTANTE**: Verifica que cada variable esté correctamente copiada

Alternativamente, algunos paneles de Dokploy permiten subir el archivo `.env` directamente.

### 5.4 Configurar Dominio

1. En la sección **"Domains"** o **"Dominios"**:
   - Agrega tu dominio: `fizzy.tudominio.com`
   - Habilita **SSL/HTTPS** (generalmente automático con Let's Encrypt)
   - **IMPORTANTE**: Asegúrate que la variable `APP_HOST` en las variables de entorno coincida exactamente con el dominio que configuraste

2. Asegúrate que tu DNS apunte correctamente:
   ```
   fizzy.tudominio.com  →  A record  →  IP_DE_TU_SERVIDOR
   ```

**Nota**: Dokploy usa Traefik como proxy reverso, por lo que NO necesitas exponer el puerto 80 directamente. El docker-compose ya está configurado con los labels de Traefik necesarios.

## 🚢 Paso 6: Deploy Inicial

1. **Guarda la configuración** en Dokploy

2. Click en **"Deploy"** o **"Desplegar"**

3. Dokploy ahora:
   - Clonará tu repositorio
   - Construirá la imagen Docker (esto puede tomar 5-10 minutos la primera vez)
   - Iniciará los servicios (base de datos y aplicación)

4. **Monitorea el proceso** en los logs de Dokploy

## 🗄️ Paso 7: Inicializar Base de Datos

Una vez que el deploy esté completo y los contenedores corriendo:

1. **Accede al contenedor de la aplicación**:
   
   En Dokploy, busca el servicio `app` y abre una terminal/shell, o desde SSH:
   
   ```bash
   # Encuentra el nombre del contenedor
   docker ps | grep fizzy
   
   # Accede al contenedor (reemplaza con el nombre correcto)
   docker exec -it NOMBRE_DEL_CONTENEDOR bash
   ```

2. **Ejecuta las migraciones**:
   
   ```bash
   bin/rails db:migrate
   ```

3. **Opcional - Cargar datos de prueba** (solo para testing):
   
   ```bash
   bin/rails db:seed
   ```

4. **Sal del contenedor**:
   ```bash
   exit
   ```

## ✅ Paso 8: Verificar el Deployment

1. **Abre tu navegador** y ve a: `https://fizzy.tudominio.com`

2. Deberías ver la página de inicio de Fizzy 🎉

3. **Prueba el registro**:
   - Intenta registrarte con tu email
   - Verifica que llegue el email con el magic link
   - Si no llega, revisa la configuración SMTP

## 🔍 Troubleshooting

### Error: "secret_key_base must be a type of String"

Esto significa que la variable `SECRET_KEY_BASE` no está configurada o está vacía en Dokploy.

**Solución rápida para testing**:

1. Genera un secret key:
   ```bash
   openssl rand -hex 64
   ```

2. En Dokploy, agrega la variable de entorno:
   - Nombre: `SECRET_KEY_BASE`
   - Valor: (pega el resultado del comando anterior)

3. Redeploya

**O usa el archivo `.env.testing`** que ya tiene valores dummy listos para usar.

### Error: "caching_sha2_password requires either TCP with TLS"

**SOLUCIONADO**: Ahora el setup usa **SQLite** en lugar de MySQL para simplificar. No verás más este error.

Si quieres usar MySQL para producción, consulta la versión completa de la guía en el repositorio original.

### Error: "port is already allocated" o "Bind for 0.0.0.0:80 failed"

Este error significa que el puerto 80 ya está en uso por el proxy de Dokploy (Traefik). **Esto es normal y esperado**.

**Solución**: El `docker-compose.yml` ya está configurado correctamente para usar Traefik. Asegúrate de:

1. No tener una sección `ports:` en el servicio `app` del docker-compose
2. Tener los labels de Traefik correctamente configurados
3. La variable `APP_HOST` debe coincidir exactamente con el dominio configurado en Dokploy
4. Redeploya después de actualizar el archivo

Si modificaste el `docker-compose.yml`, verifica que use `expose:` en lugar de `ports:`:

```yaml
app:
  expose:
    - "80"  # ✅ Correcto
  # NO uses:
  # ports:
  #   - "80:80"  # ❌ Incorrecto para Dokploy
```

### La aplicación no inicia

- Revisa los logs en Dokploy
- Verifica que todas las variables de entorno estén configuradas
- Asegúrate que el contenedor de MySQL esté healthy

```bash
# Ver logs de la aplicación
docker logs NOMBRE_CONTENEDOR_APP

# Ver logs de MySQL
docker logs NOMBRE_CONTENEDOR_DB
```

### Error de conexión a la base de datos

- Verifica que `MYSQL_ROOT_PASSWORD` sea el mismo en todos lados
- El host de la BD debe ser `db` (nombre del servicio en docker-compose)
- Espera a que MySQL esté completamente iniciado (puede tomar 30-60 segundos)
**NOTA**: Este setup ahora usa SQLite en lugar de MySQL para simplificar.

Si ves errores de base de datos:
- Asegúrate que el volumen `fizzy_storage` tenga permisos de escritura
- Verifica los logs para mensajes específicos
1. Verifica las credenciales SMTP en las variables de entorno
2. Revisa los logs de la aplicación para errores de SMTP
3. Confirma que tu proveedor SMTP permite envíos desde tu IP
4. Prueba las credenciales con un cliente SMTP simple

### Error 500 o página en blanco

- Verifica que `SECRET_KEY_BASE` esté configurado
- Revisa que las migraciones se hayan ejecutado correctamente
- Mira los logs de Rails para el error específico

### No funcionan las notificaciones push

- Verifica que `VAPID_PUBLIC_KEY` y `VAPID_PRIVATE_KEY` estén configuradas
- Asegúrate que estés usando HTTPS (requerido para notificaciones push)

## 🔄 Actualizaciones Futuras

Para deployar actualizaciones:

1. **Haz cambios en tu fork**:
   ```bash
   git add .
   git commit -m "Descripción de cambios"
   git push origin main
   ```

2. **En Dokploy**:
   - Ve a tu proyecto Fizzy
   - Click en **"Redeploy"** o **"Redesplegar"**
   - Dokploy hará pull de los cambios y reconstruirá

3. **Si hay nuevas migraciones**, ejecuta:
   ```bash
   docker exec -it CONTENEDOR_APP bin/rails db:migrate
   ```

## 📊 Mantenimiento

### Backups de Base de Datos

Es **crítico** hacer backups regulares:

```bash
# Backup manual
docker exec CONTENEDOR_MYSQL mysqldump -u root -p$MYSQL_ROOT_PASSWORD \
  fizzy_production > backup-$(date +%Y%m%d).sql

# Restaurar desde backup
docker exec -i CONTENEDOR_MYSQL mysql -u root -p$MYSQL_ROOT_PASSWORD \
  fizzy_production < backup-20231215.sql
```

Configura un cron job para backups automáticos.

### Monitoreo de Logs

```bash
# Ver logs en tiempo real
docker logs -f CONTENEDOR_APP

# Ver últimas 100 líneas
docker logs --tail 100 CONTENEDOR_APP
```

### Limpieza de Volúmenes

Los volúmenes persisten los datos. Ten cuidado al eliminarlos:

```bash
# Ver volúmenes
docker volume ls

# Eliminar volúmenes (CUIDADO: esto borra datos)
docker-compose down -v
```

## 🔐 Seguridad

- ✅ Usa contraseñas fuertes para `MYSQL_ROOT_PASSWORD`
- ✅ Mantén tu `SECRET_KEY_BASE` secreto
- ✅ No compartas tu archivo `.env`
- ✅ Habilita SSL/HTTPS siempre
- ✅ Actualiza regularmente las dependencias
- ✅ Configura firewalls apropiadamente
- ✅ Haz backups regulares

## 💡 Consejos Adicionales

1. **Recursos del servidor**: Fizzy necesita al menos:
   - 2 GB RAM
   - 20 GB disco
   - 1 vCPU

2. **Monitoreo**: Considera usar herramientas como:
   - Uptime monitoring (UptimeRobot, Pingdom)
   - Application monitoring (Sentry para errores)
   - Server monitoring (Netdata, Prometheus)

3. **Rendimiento**:
   - Configura un CDN si esperas mucho tráfico
   - Considera Redis para caché (requiere modificación)

## 🆘 Obtener Ayuda

- 📖 Documentación oficial de Fizzy: [README.md](README.md)
- 💬 Issues de GitHub: https://github.com/basecamp/fizzy/issues
- 📧 Comunidad de Dokploy: https://dokploy.com/

## 📝 Checklist Final

Antes de considerarlo completo, verifica:

- [ ] El sitio carga en `https://tudominio.com`
- [ ] Puedes registrarte y recibir el magic link por email
- [ ] Puedes iniciar sesión correctamente
- [ ] Puedes crear boards y cards
- [ ] Las notificaciones funcionan
- [ ] Has configurado backups automáticos
- [ ] El SSL está activo y funcional
- [ ] Has guardado todas tus credenciales de forma segura

¡Felicidades! 🎉 Ya tienes tu propia instancia de Fizzy corriendo.
