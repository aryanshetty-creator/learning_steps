# Copy config files to Debezium container
Write-Host "Copying configuration files..." -ForegroundColor Cyan
docker cp configs/connect-standalone.properties kafka-debezium-1:/tmp/
docker cp configs/sqlserver-connector.properties kafka-debezium-1:/tmp/

# Start connector in standalone mode
Write-Host "Starting Debezium connector in standalone mode..." -ForegroundColor Cyan
Write-Host "This will run in the background and automatically capture changes." -ForegroundColor Green

docker exec -d kafka-debezium-1 /kafka/bin/connect-standalone.sh /tmp/connect-standalone.properties /tmp/sqlserver-connector.properties

Write-Host ""
Write-Host "Connector started!" -ForegroundColor Green
Write-Host ""
Write-Host "To check if it is working:" -ForegroundColor Yellow
Write-Host "  1. Check logs: docker logs kafka-debezium-1 --tail 50" -ForegroundColor White
Write-Host "  2. Check topics: docker exec kafka /opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --list" -ForegroundColor White
Write-Host "  3. Look for topic: sqlserver.dbo.users" -ForegroundColor White
