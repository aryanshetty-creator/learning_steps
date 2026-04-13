# SQL Server + Kafka CDC System

Simple setup with SQL Server 2022, Kafka (KRaft), Debezium CDC, and Kafka UI.

## Quick Start (PowerShell)

### Start the system:
```powershell
.\setup.ps1
```

### Stop the system:
```powershell
.\stop.ps1
```

### Manual commands:
```powershell
# Start
docker-compose up -d

# Stop  
docker-compose down

# Check status
docker-compose ps
```

## Access Points

- **Kafka UI**: http://localhost:8080 (Main web interface)
- **Kafka Connect**: http://localhost:8083 (Connector management)
- **SQL Server**: localhost:1433 (sa/StrongPass@123)

## Setting Up Debezium Connector

1. Open Kafka UI at http://localhost:8080
2. Go to "Kafka Connect" tab
3. Click "Create Connector"
4. Copy/paste config from `debezium_connector.json`

## What's Included

- `docker-compose.yml` - Complete system definition
- `init-sqlserver.sql` - Automatic SQL Server CDC setup
- `debezium_connector.json` - Connector configuration
- `setup.ps1` / `stop.ps1` - PowerShell scripts

## System Requirements

- Docker Desktop with 4GB+ RAM
- PowerShell (Windows)
- Ports: 1433, 8080, 8083, 9092