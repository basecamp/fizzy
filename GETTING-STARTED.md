# Getting Started with Fizzy (Docker)

Get Fizzy running locally in 3 simple steps.

## Prerequisites

- Docker Desktop installed and running

## Steps

### 1. Generate Secrets

**Windows (PowerShell):**
```powershell
.\generate-secrets.ps1
```

**Mac/Linux:**
```bash
chmod +x generate-secrets.sh
./generate-secrets.sh
```

This creates a `.env` file with your secret keys.

### 2. Generate SSL Certificates

**Windows (PowerShell):**
```powershell
cd nginx/ssl
.\generate-cert.ps1
cd ..\..
```

**Mac/Linux:**
```bash
cd nginx/ssl
chmod +x generate-cert.sh
./generate-cert.sh
cd ../..
```

### 3. Start Everything

```bash
docker-compose up -d
```

Wait ~30 seconds for the app to start, then open your browser to:

**https://localhost**

⚠️ You'll see a certificate warning (normal for self-signed certs). Click "Advanced" → "Proceed to localhost".

## Login

Fizzy uses simple username-based authentication for local development:

1. On the login page, enter any username:
   - Use letters, numbers, and underscores only
   - Examples: `admin`, `test_user`, `john123`
2. Click "Let's go"
3. That's it! A workspace is created automatically

**No email or password needed!** Just pick a username and start using Fizzy.

## Common Commands

```bash
# View logs
docker-compose logs -f fizzy

# Check status
docker-compose ps

# Stop everything
docker-compose down

# Rebuild after code changes
docker-compose down
docker-compose build fizzy
docker-compose up -d

# Fresh start (removes all data)
docker-compose down -v
docker-compose up -d
```

## Troubleshooting

**Certificate warnings:** Normal for self-signed certs. Safe to proceed for local development.

**Port conflicts:** If ports 80/443 are in use, edit `docker-compose.yml` port mappings.

**App won't start:** Check logs with `docker-compose logs fizzy`

### Reset Database
```powershell
docker-compose exec fizzy bin/rails db:reset
```

## 🏗️ What's Running

- **Fizzy App** - Port 80 (internal) → Nginx → Port 443 (your browser)
- **Nginx Proxy** - Ports 80 (HTTP) and 443 (HTTPS)
- **SQLite Database** - In Docker volume `fizzy_fizzy_storage`

## 🔧 Configuration

Your configuration is in:
- **`.env`** - Environment variables (SECRET_KEY_BASE, VAPID keys, etc.)
- **`docker-compose.yml`** - Container configuration
- **`nginx/nginx.conf`** - Reverse proxy configuration
- **`nginx/ssl/`** - SSL certificates

## ⚠️ Important Notes

1. **This is for local testing only** - Not production-ready
2. **Self-signed SSL** - Your browser will warn you (that's OK)
3. **Placeholder VAPID keys** - Web push notifications may not work, but the app will
4. **SQLite database** - Data persists in Docker volumes

## 🆘 Troubleshooting

### Can't access the site
```powershell
# Check containers are running
docker-compose ps

# Check logs for errors
docker-compose logs
```

### Database issues
```powershell
# Reset everything
docker-compose down -v
docker-compose up -d
```

### Port conflicts
Edit `docker-compose.yml` and change ports:
```yaml
nginx:
  ports:
    - "8443:443"  # Use 8443 instead of 443
    - "8080:80"   # Use 8080 instead of 80
```
Then access at: https://localhost:8443

## 📖 Documentation

- **Full Docker guide:** [DOCKER.md](DOCKER.md)
- **Quick reference:** [DOCKER-QUICKREF.md](DOCKER-QUICKREF.md)
- **Main README:** [README.md](README.md)

## 🚀 Next Steps

1. Open https://localhost in your browser
2. Accept the SSL certificate warning
3. Login with `david@example.com`
4. Check logs for the verification code
5. Start testing Fizzy!

Enjoy! 🎊
