# Quick start script for Fizzy with Docker Compose (Windows PowerShell)

$ErrorActionPreference = "Stop"

Write-Host "🚀 Fizzy Docker Quick Start" -ForegroundColor Cyan
Write-Host "============================" -ForegroundColor Cyan
Write-Host ""

# Check if Docker is running
try {
    docker info | Out-Null
    Write-Host "✅ Docker is running" -ForegroundColor Green
} catch {
    Write-Host "❌ Docker is not running. Please start Docker Desktop first." -ForegroundColor Red
    exit 1
}

# Check if .env exists
if (-not (Test-Path .env)) {
    Write-Host ""
    Write-Host "📋 Setting up environment file..." -ForegroundColor Yellow
    
    if (-not (Test-Path .env.example)) {
        Write-Host "❌ .env.example not found!" -ForegroundColor Red
        exit 1
    }
    
    Copy-Item .env.example .env
    Write-Host "✅ Created .env from .env.example" -ForegroundColor Green
    Write-Host ""
    Write-Host "⚠️  You need to configure your .env file with secrets!" -ForegroundColor Yellow
    Write-Host "   See DOCKER.md for instructions on generating:" -ForegroundColor Gray
    Write-Host "   - SECRET_KEY_BASE" -ForegroundColor Gray
    Write-Host "   - VAPID_PUBLIC_KEY" -ForegroundColor Gray
    Write-Host "   - VAPID_PRIVATE_KEY" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Press Enter to continue after configuring .env..." -ForegroundColor Yellow
    Read-Host
}

# Check if SSL certificates exist
if (-not (Test-Path nginx/ssl/fizzy.crt) -or -not (Test-Path nginx/ssl/fizzy.key)) {
    Write-Host ""
    Write-Host "🔐 Generating SSL certificates..." -ForegroundColor Yellow
    Set-Location nginx/ssl
    & .\generate-cert.ps1
    Set-Location ..\..
    Write-Host ""
} else {
    Write-Host "✅ SSL certificates found" -ForegroundColor Green
}

# Check hosts file
Write-Host ""
Write-Host "📝 Checking hosts file configuration..." -ForegroundColor Yellow
$hostsPath = "C:\Windows\System32\drivers\etc\hosts"
$hostsContent = Get-Content $hostsPath -ErrorAction SilentlyContinue

if ($hostsContent -match "fizzy.local") {
    Write-Host "✅ fizzy.local found in hosts file" -ForegroundColor Green
} else {
    Write-Host "⚠️  fizzy.local not found in hosts file" -ForegroundColor Yellow
    Write-Host "   You need to add this line to your hosts file:" -ForegroundColor Gray
    Write-Host "   127.0.0.1 fizzy.local" -ForegroundColor White
    Write-Host ""
    Write-Host "   Hosts file location: $hostsPath" -ForegroundColor Gray
    Write-Host "   (You need to run Notepad as Administrator to edit it)" -ForegroundColor Gray
    Write-Host ""
    
    $response = Read-Host "Would you like to open the hosts file now? [y/N]"
    if ($response -eq 'y' -or $response -eq 'Y') {
        Start-Process notepad $hostsPath -Verb RunAs
        Write-Host "📝 Add this line: 127.0.0.1 fizzy.local" -ForegroundColor Yellow
        Write-Host "Press Enter after adding the entry..." -ForegroundColor Yellow
        Read-Host
    }
}

# Build and start
Write-Host ""
Write-Host "🔨 Building Docker images..." -ForegroundColor Yellow
docker-compose build

Write-Host ""
Write-Host "🚀 Starting services..." -ForegroundColor Yellow
docker-compose up -d

Write-Host ""
Write-Host "⏳ Waiting for services to be healthy..." -ForegroundColor Yellow
Start-Sleep -Seconds 5

# Check if services are running
$services = docker-compose ps
if ($services -match "Up") {
    Write-Host ""
    Write-Host "✅ Fizzy is running!" -ForegroundColor Green
    Write-Host ""
    Write-Host "🌐 Access Fizzy at:" -ForegroundColor Cyan
    Write-Host "   https://fizzy.local" -ForegroundColor White
    Write-Host ""
    Write-Host "📧 Default login email: david@example.com" -ForegroundColor Cyan
    Write-Host "   (Check logs for verification code)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "📋 Useful commands:" -ForegroundColor Cyan
    Write-Host "   docker-compose logs -f          # View logs" -ForegroundColor Gray
    Write-Host "   docker-compose down             # Stop services" -ForegroundColor Gray
    Write-Host "   docker-compose restart          # Restart services" -ForegroundColor Gray
    Write-Host ""
    Write-Host "📖 See DOCKER.md for more information" -ForegroundColor Cyan
    Write-Host ""
    
    $response = Read-Host "Open logs now? [y/N]"
    if ($response -eq 'y' -or $response -eq 'Y') {
        docker-compose logs -f
    }
} else {
    Write-Host ""
    Write-Host "❌ Services failed to start. Check logs:" -ForegroundColor Red
    Write-Host "   docker-compose logs" -ForegroundColor Gray
    exit 1
}
