# PowerShell script to stop all services

Write-Host "🛑 Stopping SQL Server + Kafka CDC System" -ForegroundColor Red
Write-Host "=" * 50

docker-compose down

Write-Host "✅ All services stopped" -ForegroundColor Green