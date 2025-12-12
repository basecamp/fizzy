# Stop Fizzy Docker containers

Write-Host "🛑 Stopping Fizzy Docker containers..." -ForegroundColor Cyan
Write-Host ""

$response = Read-Host "Do you want to remove data volumes too? [y/N]"

if ($response -eq 'y' -or $response -eq 'Y') {
    Write-Host "Stopping containers and removing volumes..." -ForegroundColor Yellow
    docker-compose down -v
    Write-Host "✅ Containers stopped and data removed" -ForegroundColor Green
} else {
    Write-Host "Stopping containers (keeping data)..." -ForegroundColor Yellow
    docker-compose down
    Write-Host "✅ Containers stopped (data preserved)" -ForegroundColor Green
}

Write-Host ""
Write-Host "To start again, run: docker-compose up -d" -ForegroundColor Cyan
