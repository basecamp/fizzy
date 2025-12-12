# Docker Quick Reference

## Initial Setup

```bash
# 1. Generate secrets
.\generate-secrets.ps1        # Windows
./generate-secrets.sh         # Mac/Linux

# 2. Generate SSL certificates
cd nginx/ssl
.\generate-cert.ps1           # Windows
./generate-cert.sh            # Mac/Linux
cd ..\..                      # or cd ../.. on Mac/Linux

# 3. Start everything
docker-compose up -d

# 4. Open browser
# https://localhost
```

## Essential Commands

```bash
# 1. Generate secrets and create .env file
chmod +x generate-secrets.sh
./generate-secrets.sh

# 2. Run the quick start script (handles everything)
chmod +x docker-start.sh
./docker-start.sh
```

## Manual Setup

### 1. Generate SSL Certificates
```powershell
# Windows
cd nginx/ssl
.\generate-cert.ps1

# Linux/Mac
cd nginx/ssl
chmod +x generate-cert.sh
./generate-cert.sh
cd ../..
```

### 2. Configure Environment
```bash
cp .env.example .env
# Edit .env with generated secrets
```

### 3. Access URL
The application will be available at:
- **https://localhost** (HTTPS)
- **http://localhost** (redirects to HTTPS)

No hosts file modification needed.

### 4. Build and Run
```bash
docker-compose build
docker-compose up -d
```

### 5. Access & Login
- URL: https://localhost
- Login: Enter any username (letters, numbers, underscores)
- A workspace will be created automatically for new usernames

## Common Commands

```bash
# View logs
docker-compose logs -f

# Stop
docker-compose down

# Restart
docker-compose restart

# Rebuild
docker-compose build
docker-compose up -d

# Rails console
docker-compose exec fizzy bin/rails console

# Reset database
docker-compose exec fizzy bin/rails db:reset
```

## Architecture

- **fizzy** - Rails app on port 80 (internal)
- **nginx** - Reverse proxy on ports 443 (HTTPS) and 80 (HTTP redirect)
- **SQLite** - Database in Docker volume
- **Self-signed SSL** - Certificate for local HTTPS

## Environment Variables

Required in `.env`:
- `SECRET_KEY_BASE` - Rails secret (generate with `rails secret`)
- `VAPID_PUBLIC_KEY` - Push notification key
- `VAPID_PRIVATE_KEY` - Push notification key

Optional:
- `SMTP_ADDRESS` - Email server
- `SMTP_USERNAME` - Email username
- `SMTP_PASSWORD` - Email password
- `MAILER_FROM_ADDRESS` - From email address
- `MULTI_TENANT` - Enable multi-tenant mode (default: false)

## Troubleshooting

### Browser shows security warning
- Normal for self-signed certificates
- Click "Advanced" → "Proceed to fizzy.local"

### Can't access https://localhost
- Check containers are running: `docker-compose ps`
- Check logs: `docker-compose logs`
- Ensure ports 80 and 443 are not in use

### Port conflicts
Edit `docker-compose.yml` ports section:
```yaml
nginx:
  ports:
    - "8443:443"  # Use different port
    - "8080:80"
```
Then access at: https://localhost:8443

### Database issues
```bash
# Reset everything
docker-compose down -v
docker-compose up -d
```

## Security Notes

⚠️ **This setup is for local testing only!**

For production:
- Use proper SSL certificates (Let's Encrypt)
- Use PostgreSQL/MySQL instead of SQLite
- Properly secure secrets
- Follow the production deployment guide

## More Information

See [DOCKER.md](DOCKER.md) for detailed documentation.
