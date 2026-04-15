# SQL Server + Kafka CDC System

Simple setup with SQL Server 2022, Kafka (KRaft), Debezium CDC, and Kafka UI.

## 📁 Project Structure

```
kafka/
├── configs/
│   └── debezium_connector.json    # Main connector configuration
├── docs/                          # Documentation
│   ├── BEGINNER_GUIDE.md
│   ├── OUR_SESSION_FLOW.md
│   ├── SETUP_SUMMARY.md
│   └── CONNECTOR_SOLUTION.md
├── scripts/                       # Helper scripts
│   ├── setup.ps1
│   ├── stop.ps1
│   └── test_kafka.py
├── docker-compose.yml             # Main configuration
├── init-sqlserver.sql             # SQL Server CDC setup
└── README.md
```

## Quick Start (PowerShell)

### Start the system:
```powershell
.\scripts\setup.ps1
```

### Stop the system:
```powershell
.\scripts\stop.ps1
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
- **SQL Server**: localhost:1433 (sa/YourStrong@Passw0rd)

## Setting Up Debezium Connector

1. Open Kafka UI at http://localhost:8080
2. Go to "Kafka Connect" tab
3. Click "Create Connector"
4. Copy/paste config from `configs/debezium_connector.json`

## What's Included

- `docker-compose.yml` - Complete system definition
- `init-sqlserver.sql` - Automatic SQL Server CDC setup
- `configs/debezium_connector.json` - Connector configuration
- `scripts/setup.ps1` / `scripts/stop.ps1` - PowerShell scripts
- `scripts/test_kafka.py` - Test Kafka messaging

## System Requirements

- Docker Desktop with 4GB+ RAM
- PowerShell (Windows)
- Ports: 1433, 8080, 8083, 9092, 9094

## Documentation

See the `docs/` folder for detailed guides:
- **BEGINNER_GUIDE.md** - Complete learning guide
- **OUR_SESSION_FLOW.md** - Step-by-step session flow
- **SETUP_SUMMARY.md** - Setup summary for team lead
- **CONNECTOR_SOLUTION.md** - Connector timeout solutions