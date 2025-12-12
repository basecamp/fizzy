# PowerShell script to generate self-signed SSL certificates for local Fizzy development

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$SslDir = $ScriptDir

Write-Host "🔐 Generating self-signed SSL certificate for Fizzy..." -ForegroundColor Cyan
Write-Host "📁 SSL directory: $SslDir" -ForegroundColor Gray

# Create directory if it doesn't exist
if (-not (Test-Path $SslDir)) {
    New-Item -ItemType Directory -Path $SslDir -Force | Out-Null
}

$certPath = Join-Path $SslDir "fizzy.crt"
$keyPath = Join-Path $SslDir "fizzy.key"

# Check if OpenSSL is available
$opensslCmd = Get-Command openssl -ErrorAction SilentlyContinue

if ($opensslCmd) {
    Write-Host "Using OpenSSL to generate certificate..." -ForegroundColor Yellow
    
    # Generate private key
    Write-Host "Generating private key..." -ForegroundColor Gray
    & openssl genrsa -out $keyPath 2048 2>$null
    
    # Generate certificate
    Write-Host "Generating self-signed certificate..." -ForegroundColor Gray
    & openssl req -new -x509 -key $keyPath -out $certPath -days 365 `
        -subj "/C=US/ST=State/L=City/O=Fizzy Local/CN=localhost" `
        -addext "subjectAltName=DNS:localhost,DNS:*.localhost,IP:127.0.0.1" 2>$null
    
} else {
    Write-Host "OpenSSL not found. Using .NET to generate certificate..." -ForegroundColor Yellow
    
    # Use .NET to create certificate
    $cert = New-SelfSignedCertificate `
        -DnsName "localhost", "127.0.0.1" `
        -CertStoreLocation "cert:\CurrentUser\My" `
        -NotAfter (Get-Date).AddYears(1) `
        -KeySpec KeyExchange `
        -KeyExportPolicy Exportable
    
    # Export certificate
    $certBytes = $cert.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Cert)
    [System.IO.File]::WriteAllBytes($certPath, $certBytes)
    
    # Export private key (this is more complex with .NET)
    $keyBytes = $cert.PrivateKey.Key.Export([System.Security.Cryptography.CngKeyBlobFormat]::Pkcs8PrivateBlob)
    
    # Convert to PEM format
    $keyPem = "-----BEGIN PRIVATE KEY-----`n"
    $keyPem += [Convert]::ToBase64String($keyBytes, [System.Base64FormattingOptions]::InsertLineBreaks)
    $keyPem += "`n-----END PRIVATE KEY-----"
    [System.IO.File]::WriteAllText($keyPath, $keyPem)
    
    # Also convert cert to PEM
    $certPem = "-----BEGIN CERTIFICATE-----`n"
    $certPem += [Convert]::ToBase64String($certBytes, [System.Base64FormattingOptions]::InsertLineBreaks)
    $certPem += "`n-----END CERTIFICATE-----"
    [System.IO.File]::WriteAllText($certPath, $certPem)
    
    # Remove from certificate store
    Remove-Item -Path "cert:\CurrentUser\My\$($cert.Thumbprint)" -Force
}

Write-Host "`n✅ SSL certificate generated successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "Certificate: $certPath" -ForegroundColor Gray
Write-Host "Private Key: $keyPath" -ForegroundColor Gray
Write-Host ""
Write-Host "⚠️  This is a self-signed certificate. Your browser will show a security warning." -ForegroundColor Yellow
Write-Host "   Click 'Advanced' and 'Proceed to localhost' to accept it." -ForegroundColor Gray
Write-Host ""
Write-Host "🌐 You can access Fizzy at: https://localhost" -ForegroundColor Cyan
