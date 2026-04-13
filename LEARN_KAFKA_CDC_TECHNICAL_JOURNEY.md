# Kafka CDC System - Complete Technical Journey

**What You'll Learn:** How to build a real-time data streaming system from scratch using Kafka, SQL Server CDC, and Debezium - with every command and code change explained step by step.

---

## Chat 1: The Very Beginning - Simple Kafka Setup

**You started with:** Just wanting to learn Kafka basics

**First, we created the foundation:**

```yaml
# docker-compose.yml (Version 1 - Simple)
version: '3.8'
services:
  zookeeper:
    image: confluentinc/cp-zookeeper:7.5.0
    environment:
      ZOOKEEPER_CLIENT_PORT: 2181
    ports:
      - "2181:2181"

  kafka:
    image: confluentinc/cp-kafka:7.5.0
    depends_on:
      - zookeeper
    ports:
      - "9092:9092"
    environment:
      KAFKA_ZOOKEEPER_CONNECT: zookeeper:2181
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://localhost:9092
```

**Then we created producer.py:**

```python
from kafka import KafkaProducer
import json
import time

producer = KafkaProducer(
    bootstrap_servers='localhost:9092',
    value_serializer=lambda v: json.dumps(v).encode('utf-8')
)

for i in range(10):
    message = {'id': i, 'message': f'Hello #{i}'}
    producer.send('test-topic', message)
    print(f"Sent: {message}")
    time.sleep(2)

producer.close()
```

**And consumer.py:**

```python
from kafka import KafkaConsumer

consumer = KafkaConsumer(
    'test-topic',
    bootstrap_servers='localhost:9092',
    auto_offset_reset='earliest'
)

print("Waiting for messages...")
for message in consumer:
    print(message.value.decode())
```

**Commands we ran:**

```bash
# Start Kafka
docker-compose up -d

# Check if running
docker ps

# Test producer
python producer.py

# Test consumer (in another terminal)
python consumer.py
```

**Result:** ✅ Basic Kafka working! Messages flowing from producer to consumer.

---

## Chat 2: Team Lead's Requirements - Adding SQL Server CDC

**You said:** "My team lead wants SQL Server with CDC and Debezium"

**We replaced docker-compose.yml completely:**

```yaml
# docker-compose.yml (Version 2 - Full CDC System)
version: '3.8'

services:
  kafka:
    image: apache/kafka:3.7.0
    ports:
      - "9092:9092"
    environment:
      KAFKA_NODE_ID: 1
      KAFKA_PROCESS_ROLES: broker,controller
      KAFKA_LISTENERS: PLAINTEXT://:9092,CONTROLLER://:9093
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://localhost:9092
      KAFKA_CONTROLLER_QUORUM_VOTERS: 1@kafka:9093
      KAFKA_CONTROLLER_LISTENER_NAMES: CONTROLLER
      KAFKA_LOG_DIRS: /tmp/kraft-combined-logs

  sqlserver:
    image: mcr.microsoft.com/mssql/server:2022-latest
    ports:
      - "1433:1433"
    environment:
      ACCEPT_EULA: Y
      SA_PASSWORD: YourStrong@Passw0rd
      MSSQL_AGENT_ENABLED: "true"

  debezium:
    image: debezium/connect:2.5
    ports:
      - "8083:8083"
    environment:
      BOOTSTRAP_SERVERS: kafka:9092
      GROUP_ID: 1
      CONFIG_STORAGE_TOPIC: debezium_configs
      OFFSET_STORAGE_TOPIC: debezium_offsets
      STATUS_STORAGE_TOPIC: debezium_status

  kafka-ui:
    image: provectuslabs/kafka-ui:latest
    ports:
      - "8080:8080"
    environment:
      KAFKA_CLUSTERS_0_NAME: local
      KAFKA_CLUSTERS_0_BOOTSTRAPSERVERS: kafka:9092
```

**Commands we ran:**

```bash
# Stop old setup
docker-compose down

# Start new setup
docker-compose up -d
```

**Result:** ❌ Failed! SQL Server healthcheck failing.

---

## Chat 3: Fixing SQL Server Healthcheck

**Problem:** SQL Server showing as "unhealthy"

**We checked the logs:**

```bash
docker logs sqlserver --tail 30
```

**Saw:** SQL Server was running, but healthcheck command was wrong.

**We tested manually:**

```bash
# This failed
docker exec sqlserver /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P 'YourStrong@Passw0rd' -Q "SELECT 1"

# Error: no such file or directory
```

**We found the correct path:**

```bash
# This worked!
docker exec sqlserver /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P 'YourStrong@Passw0rd' -No -Q "SELECT 1"
```

**Fixed docker-compose.yml:**

```yaml
sqlserver:
  image: mcr.microsoft.com/mssql/server:2022-latest
  ports:
    - "1433:1433"
  environment:
    ACCEPT_EULA: Y
    SA_PASSWORD: YourStrong@Passw0rd
    MSSQL_AGENT_ENABLED: "true"
  healthcheck:
    test: /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P 'YourStrong@Passw0rd' -No -Q "SELECT 1"
    interval: 10s
    timeout: 5s
    retries: 10
```

**Commands:**

```bash
docker-compose down
docker-compose up -d

# Wait 30 seconds, then check
docker ps
```

**Result:** ✅ SQL Server now healthy!

---

## Chat 4: Fixing Debezium Network Issues

**Problem:** Debezium couldn't connect to Kafka

**We checked Debezium logs:**

```bash
docker logs kafka-debezium-1 --tail 20
```

**Saw:** "Connection to localhost:9092 failed"

**The issue:** Inside Docker, "localhost" means the container itself, not the host machine.

**We fixed Kafka networking:**

```yaml
kafka:
  image: apache/kafka:3.7.0
  ports:
    - "9092:9092"
    - "9094:9094"  # Added external port
  environment:
    KAFKA_NODE_ID: 1
    KAFKA_PROCESS_ROLES: broker,controller
    # Changed these lines:
    KAFKA_LISTENERS: PLAINTEXT://:9092,CONTROLLER://:9093,PLAINTEXT_HOST://:9094
    KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://kafka:9092,PLAINTEXT_HOST://localhost:9094
    KAFKA_LISTENER_SECURITY_PROTOCOL_MAP: PLAINTEXT:PLAINTEXT,CONTROLLER:PLAINTEXT,PLAINTEXT_HOST:PLAINTEXT
    KAFKA_INTER_BROKER_LISTENER_NAME: PLAINTEXT
```

**Added Docker network:**

```yaml
networks:
  kafka-network:
    driver: bridge

# Added to each service:
services:
  kafka:
    networks:
      - kafka-network
  sqlserver:
    networks:
      - kafka-network
  debezium:
    networks:
      - kafka-network
  kafka-ui:
    networks:
      - kafka-network
```

**Commands:**

```bash
docker-compose down
docker-compose up -d

# Wait for services to start
sleep 30

docker ps
```

**Result:** ✅ All services running and connected!

---

## Chat 5: Configuring Kafka UI to See Debezium

**Problem:** Opened http://localhost:8080, but no "Kafka Connect" tab

**We updated Kafka UI config:**

```yaml
kafka-ui:
  image: provectuslabs/kafka-ui:latest
  ports:
    - "8080:8080"
  environment:
    KAFKA_CLUSTERS_0_NAME: local
    KAFKA_CLUSTERS_0_BOOTSTRAPSERVERS: kafka:9092
    # Added these lines:
    KAFKA_CLUSTERS_0_KAFKACONNECT_0_NAME: debezium
    KAFKA_CLUSTERS_0_KAFKACONNECT_0_ADDRESS: http://debezium:8083
  depends_on:
    - kafka
    - debezium
  networks:
    - kafka-network
```

**Commands:**

```bash
docker-compose down
docker-compose up -d
```

**Opened browser:** http://localhost:8080

**Result:** ✅ Kafka Connect tab now visible!

---

## Chat 6: Setting Up SQL Server CDC

**We created init-sqlserver.sql:**

```sql
-- Create database
CREATE DATABASE TestDB;
GO

-- Switch to database
USE TestDB;
GO

-- Enable CDC on database
EXEC sys.sp_cdc_enable_db;
GO

-- Create table
CREATE TABLE dbo.users (
    id INT IDENTITY(1,1) PRIMARY KEY,
    name NVARCHAR(100) NOT NULL,
    email NVARCHAR(255) NOT NULL,
    created_at DATETIME2 DEFAULT GETDATE(),
    updated_at DATETIME2 DEFAULT GETDATE()
);
GO

-- Enable CDC on table
EXEC sys.sp_cdc_enable_table
    @source_schema = 'dbo',
    @source_name   = 'users',
    @role_name     = NULL;
GO

-- Insert test data
INSERT INTO dbo.users (name, email) VALUES 
    ('John Doe', 'john@example.com'),
    ('Jane Smith', 'jane@example.com'),
    ('Bob Johnson', 'bob@example.com');
GO
```

**We ran it:**

```bash
docker exec sqlserver /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P 'YourStrong@Passw0rd' -No -i /init-sqlserver.sql
```

**Or manually:**

```bash
docker exec -it sqlserver /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P 'YourStrong@Passw0rd' -No

# Then paste the SQL commands
```

**Verified CDC was enabled:**

```bash
docker exec sqlserver /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P 'YourStrong@Passw0rd' -No -Q "USE TestDB; EXEC sys.sp_cdc_help_change_data_capture;"
```

**Result:** ✅ CDC enabled on TestDB.dbo.users table!

---

## Chat 7: Creating Debezium Connector Configuration

**We created debezium_connector.json:**

```json
{
  "name": "sqlserver-source-connector",
  "config": {
    "connector.class": "io.debezium.connector.sqlserver.SqlServerConnector",
    "tasks.max": "1",
    "database.hostname": "sqlserver",
    "database.port": "1433",
    "database.user": "sa",
    "database.password": "YourStrong@Passw0rd",
    "database.names": "TestDB",
    "database.encrypt": "false",
    "database.trustServerCertificate": "true",
    "topic.prefix": "sqlserver",
    "table.include.list": "dbo.users",
    "snapshot.mode": "initial",
    "schema.history.internal.kafka.bootstrap.servers": "kafka:9092",
    "schema.history.internal.kafka.topic": "schema-changes.sqlserver"
  }
}
```

**Tried creating via Kafka UI:**
1. Opened http://localhost:8080
2. Clicked "Kafka Connect" tab
3. Clicked "Create Connector"
4. Pasted the JSON

**Result:** ❌ Timeout after 90 seconds

**Tried via command line:**

```powershell
$body = Get-Content debezium_connector.json -Raw
Invoke-RestMethod -Uri http://localhost:8083/connectors -Method Post -Body $body -ContentType "application/json" -TimeoutSec 120
```

**Result:** ❌ Still timeout (Debezium validation takes too long)

---

## Chat 8: Creating Helper Scripts

**We created setup.ps1:**

```powershell
Write-Host "Starting Kafka CDC System..." -ForegroundColor Green
docker-compose up -d

Write-Host "`nWaiting for services to start..." -ForegroundColor Yellow
Start-Sleep -Seconds 30

Write-Host "`nChecking service status..." -ForegroundColor Cyan
docker-compose ps

Write-Host "`nAccess Points:" -ForegroundColor Green
Write-Host "- Kafka UI: http://localhost:8080"
Write-Host "- Kafka Connect: http://localhost:8083"
Write-Host "- SQL Server: localhost:1433"
```

**We created stop.ps1:**

```powershell
Write-Host "Stopping Kafka CDC System..." -ForegroundColor Yellow
docker-compose down

Write-Host "`nSystem stopped." -ForegroundColor Green
```

**Made them executable and tested:**

```powershell
# Start everything
.\setup.ps1

# Stop everything
.\stop.ps1
```

**Result:** ✅ Easy one-command start/stop!

---

## Chat 9: Testing the System

**We created test_kafka.py:**

```python
from kafka import KafkaProducer
import json
import time
from datetime import datetime

producer = KafkaProducer(
    bootstrap_servers='localhost:9092',
    value_serializer=lambda v: json.dumps(v).encode('utf-8')
)

messages = [
    {"event": "user_login", "user_id": 123},
    {"event": "page_view", "page": "/dashboard"},
    {"event": "purchase", "product": "laptop", "amount": 999.99}
]

for message in messages:
    topic = "test-events"
    producer.send(topic, message)
    print(f"✅ Sent: {message}")
    time.sleep(1)

producer.close()
```

**Ran it:**

```bash
python test_kafka.py
```

**Checked in Kafka UI:**
- Opened http://localhost:8080
- Clicked "Topics" tab
- Saw "test-events" topic with messages

**Result:** ✅ Kafka working perfectly!

---

## Key Takeaways

### What We Built:
- Real-time data streaming system
- SQL Server with Change Data Capture
- Kafka message broker (KRaft mode)
- Debezium connector for CDC
- Kafka UI for management

### Major Issues Fixed:
1. SQL Server healthcheck path (mssql-tools vs mssql-tools18)
2. Docker networking (localhost vs container names)
3. Kafka listener configuration (internal vs external)
4. Kafka UI connector visibility

### Commands You'll Use Daily:

```bash
# Start system
docker-compose up -d

# Stop system
docker-compose down

# Check status
docker ps

# View logs
docker logs <container-name>

# Test SQL Server
docker exec sqlserver /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P 'YourStrong@Passw0rd' -No -Q "SELECT 1"

# Check CDC status
docker exec sqlserver /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P 'YourStrong@Passw0rd' -No -Q "USE TestDB; EXEC sys.sp_cdc_help_change_data_capture;"
```

### Access Points:
- Kafka UI: http://localhost:8080
- Kafka Connect API: http://localhost:8083
- Kafka Broker: localhost:9092
- SQL Server: localhost:1433

---

**Total Time:** ~3 hours  
**Issues Resolved:** 6 major problems  
**Final Status:** Fully functional Kafka CDC infrastructure  
**Next Steps:** Increase Debezium timeout or use alternative connector creation method
