# PowerShell Setup Script for SQL Server + Kafka CDC System
# Run this script to start the entire system

Write-Host "🚀 Starting SQL Server + Kafka CDC System" -ForegroundColor Green
Write-Host "=" * 50

# Start all services
Write-Host "📦 Starting Docker containers..." -ForegroundColor Yellow
docker-compose up -d

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to start Docker services" -ForegroundColor Red
    exit 1
}

Write-Host "⏳ Waiting for services to start..." -ForegroundColor Yellow
Start-Sleep -Seconds 30

# Check if services are running
Write-Host "🔍 Checking service status..." -ForegroundColor Yellow
docker-compose ps

Write-Host ""
Write-Host "🎉 System should be ready!" -ForegroundColor Green
Write-Host "=" * 50
Write-Host "📊 Kafka UI:        http://localhost:8080" -ForegroundColor Cyan
Write-Host "🔌 Kafka Connect:   http://localhost:8083" -ForegroundColor Cyan  
Write-Host "📋 Schema Registry: http://localhost:8081" -ForegroundColor Cyan
Write-Host "🗄️  SQL Server:     localhost:1433 (sa/Strong!Passw0rd)" -ForegroundColor Cyan

Write-Host ""
Write-Host "📝 Next Steps:" -ForegroundColor Yellow
Write-Host "1. Open Kafka UI at http://localhost:8080"
Write-Host "2. Connect to SQL Server and run setup_cdc.sql"
Write-Host "3. Configure Debezium connector via Kafka UI"
Write-Host ""
Write-Host "🛑 To stop everything: docker-compose down" -ForegroundColor Red