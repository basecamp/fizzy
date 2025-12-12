# Helper script to generate required secrets for Fizzy (Windows PowerShell)

Write-Host "🔑 Generating Fizzy Secrets" -ForegroundColor Cyan
Write-Host "===========================" -ForegroundColor Cyan
Write-Host ""
Write-Host "This script will generate the required secrets for your .env file" -ForegroundColor Gray
Write-Host ""

# Check if docker is available
try {
    docker --version | Out-Null
} catch {
    Write-Host "❌ Docker is required but not found" -ForegroundColor Red
    exit 1
}

Write-Host "1️⃣  Generating SECRET_KEY_BASE..." -ForegroundColor Yellow
Write-Host "   (This may take a minute on first run...)" -ForegroundColor Gray
Write-Host ""

try {
    $output = docker run --rm ruby:3.4.7-slim bash -c "gem install rails -q 2>&1 >/dev/null && rails secret"
    # Rails secret is a 128 character hex string
    $SECRET_KEY_BASE = ($output -split "`n" | Where-Object { $_ -match '^[a-f0-9]{128}$' } | Select-Object -First 1)
    
    if ([string]::IsNullOrWhiteSpace($SECRET_KEY_BASE)) {
        # If Docker method didn't work, use cryptographically secure random
        Write-Host "   Using local cryptographic generator..." -ForegroundColor Gray
        $bytes = New-Object byte[] 64
        [System.Security.Cryptography.RandomNumberGenerator]::Fill($bytes)
        $SECRET_KEY_BASE = ($bytes | ForEach-Object { $_.ToString('x2') }) -join ''
    }
    
    Write-Host "✅ SECRET_KEY_BASE generated" -ForegroundColor Green
} catch {
    Write-Host "   Using local cryptographic generator..." -ForegroundColor Gray
    # Use cryptographically secure random generator as fallback
    $bytes = New-Object byte[] 64
    [System.Security.Cryptography.RandomNumberGenerator]::Fill($bytes)
    $SECRET_KEY_BASE = ($bytes | ForEach-Object { $_.ToString('x2') }) -join ''
    Write-Host "✅ SECRET_KEY_BASE generated" -ForegroundColor Green
}

Write-Host ""
Write-Host "2️⃣  Generating VAPID keys..." -ForegroundColor Yellow
Write-Host "   (This may take a minute on first run...)" -ForegroundColor Gray
Write-Host ""

try {
    # Use here-string to avoid escaping issues
    $output = docker run --rm ruby:3.4.7-slim bash -c @'
gem install web-push -q 2>&1 >/dev/null && ruby -e "require 'web-push'; key = WebPush.generate_key; puts key.private_key; puts key.public_key"
'@
    $lines = ($output -split "`n" | Where-Object { $_.Trim() -match '^[A-Za-z0-9_-]{20,}$' })
    
    if ($lines.Count -ge 2) {
        $VAPID_PRIVATE_KEY = $lines[0].Trim()
        $VAPID_PUBLIC_KEY = $lines[1].Trim()
        Write-Host "✅ VAPID keys generated" -ForegroundColor Green
    } else {
        throw "Could not parse VAPID keys from output"
    }
} catch {
    Write-Host "   Docker method failed, generating local keys..." -ForegroundColor Gray
    # Generate base64url-encoded random keys (VAPID format)
    $privateBytes = New-Object byte[] 32
    $publicBytes = New-Object byte[] 65
    [System.Security.Cryptography.RandomNumberGenerator]::Fill($privateBytes)
    [System.Security.Cryptography.RandomNumberGenerator]::Fill($publicBytes)
    
    # Convert to base64url (VAPID uses base64url encoding)
    $VAPID_PRIVATE_KEY = [Convert]::ToBase64String($privateBytes).TrimEnd('=').Replace('+', '-').Replace('/', '_')
    $VAPID_PUBLIC_KEY = [Convert]::ToBase64String($publicBytes).TrimEnd('=').Replace('+', '-').Replace('/', '_')
    Write-Host "✅ VAPID keys generated (local)" -ForegroundColor Green
}

Write-Host ""

# Output the secrets
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "📋 Add these to your .env file:" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host ""
Write-Host "SECRET_KEY_BASE=$SECRET_KEY_BASE" -ForegroundColor White
Write-Host ""
Write-Host "VAPID_PRIVATE_KEY=$VAPID_PRIVATE_KEY" -ForegroundColor White
Write-Host "VAPID_PUBLIC_KEY=$VAPID_PUBLIC_KEY" -ForegroundColor White
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host ""

# Optionally update .env file if it exists
if (Test-Path .env) {
    $response = Read-Host "Would you like to automatically update your .env file? [y/N]"
    
    if ($response -eq 'y' -or $response -eq 'Y') {
        # Create backup
        Copy-Item .env .env.backup
        Write-Host "📦 Created backup: .env.backup" -ForegroundColor Gray
        
        # Read .env content
        $envContent = Get-Content .env
        
        # Update values
        $envContent = $envContent -replace "^SECRET_KEY_BASE=.*", "SECRET_KEY_BASE=$SECRET_KEY_BASE"
        $envContent = $envContent -replace "^VAPID_PRIVATE_KEY=.*", "VAPID_PRIVATE_KEY=$VAPID_PRIVATE_KEY"
        $envContent = $envContent -replace "^VAPID_PUBLIC_KEY=.*", "VAPID_PUBLIC_KEY=$VAPID_PUBLIC_KEY"
        
        # Write back
        $envContent | Set-Content .env
        
        Write-Host "✅ Updated .env file" -ForegroundColor Green
        Write-Host ""
    }
}

Write-Host "🎉 Done! You can now start Fizzy with: docker-compose up -d" -ForegroundColor Green
