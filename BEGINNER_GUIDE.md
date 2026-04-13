# Kafka CDC Setup - Complete Beginner's Guide

## 📚 Table of Contents
1. [What is Kafka CDC?](#what-is-kafka-cdc)
2. [Understanding the Components](#understanding-the-components)
3. [Step-by-Step Setup Process](#step-by-step-setup-process)
4. [Common Issues and Solutions](#common-issues-and-solutions)
5. [How to Verify Everything Works](#how-to-verify-everything-works)
6. [Key Learnings](#key-learnings)

---

## 🎯 What is Kafka CDC?

### **CDC = Change Data Capture**

Imagine you have a database where data changes constantly (new orders, updated customers, etc.). You want other systems to know about these changes in real-time without:
- Writing custom code
- Polling the database constantly
- Missing any changes

**That's what CDC does!**

```
SQL Server Database
    ↓ (Someone inserts/updates/deletes data)
    ↓
Debezium captures the change
    ↓
Sends it to Kafka
    ↓
Other applications consume the change
```

### **Real-World Example:**
```
E-commerce scenario:
1. Customer places order → SQL Server
2. Debezium captures: "New order #123"
3. Kafka broadcasts this change
4. Email service → Sends confirmation
5. Inventory service → Updates stock
6. Analytics service → Updates dashboard

All happen automatically in real-time!
```

---

## 🧩 Understanding the Components

### **1. Kafka (The Message Highway)**
- **What it does**: Stores and distributes messages
- **Think of it as**: A super-fast postal service
- **Port**: 9092
- **Why we need it**: Central hub for all data streams

### **2. Zookeeper vs KRaft**
**Old Way (Zookeeper):**
```
Zookeeper (Manager) ← → Kafka (Worker)
```
- Zookeeper manages Kafka cluster
- Two separate services to maintain

**New Way (KRaft):**
```
Kafka (Manager + Worker combined)
```
- Kafka manages itself
- Simpler, faster, fewer moving parts
- **We used KRaft mode!**

### **3. SQL Server with CDC**
- **What it does**: Your database with change tracking enabled
- **CDC Feature**: Tracks every INSERT/UPDATE/DELETE
- **SQL Server Agent**: Background service that captures changes
- **Port**: 1433

### **4. Debezium (The Bridge)**
- **What it does**: Reads SQL Server changes and sends to Kafka
- **Think of it as**: A translator between SQL Server and Kafka
- **Port**: 8083
- **Type**: Kafka Connect connector

### **5. Kafka UI (The Dashboard)**
- **What it does**: Visual interface to see everything
- **Port**: 8080
- **Features**: View topics, messages, connectors, consumers

---

## 📋 Step-by-Step Setup Process

### **Phase 1: Understanding the Architecture**

```
┌─────────────────────────────────────────────────────────┐
│                    Docker Network                        │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌─────────┐ │
│  │   SQL    │→ │ Debezium │→ │  Kafka   │→ │ Kafka   │ │
│  │  Server  │  │ Connect  │  │          │  │   UI    │ │
│  └──────────┘  └──────────┘  └──────────┘  └─────────┘ │
│      :1433         :8083         :9092         :8080    │
└─────────────────────────────────────────────────────────┘
```

### **Phase 2: Initial Setup (What We Started With)**

#### **Step 1: Simple Kafka Setup**
```yaml
# First docker-compose.yml (Simple version)
services:
  zookeeper:
    image: confluentinc/cp-zookeeper:7.5.0
    ports:
      - "2181:2181"
  
  kafka:
    image: confluentinc/cp-kafka:7.5.0
    ports:
      - "9092:9092"
    depends_on:
      - zookeeper
```

**What we learned:**
- ✅ Basic Kafka needs Zookeeper
- ✅ Port 9092 is standard for Kafka
- ❌ This is the old way (Zookeeper-based)

#### **Step 2: Testing Basic Kafka**
Created simple Python scripts:
- `producer.py` - Sends messages to Kafka
- `consumer.py` - Receives messages from Kafka

**Purpose**: Verify Kafka works before adding complexity

```python
# Simple test flow:
Producer sends: {"message": "Hello Kafka"}
    ↓
Kafka stores it in a topic
    ↓
Consumer receives: {"message": "Hello Kafka"}
```

### **Phase 3: Upgrading to Modern Setup**

#### **Step 3: Switch to KRaft Mode**
**Why?** Simpler, no Zookeeper needed

```yaml
# New Kafka configuration
kafka:
  image: apache/kafka:3.7.0
  environment:
    KAFKA_PROCESS_ROLES: broker,controller  # Does both jobs!
    KAFKA_NODE_ID: 1
    # No Zookeeper needed!
```

**Key Learning:**
- KRaft = Kafka manages itself
- One less service to worry about
- Modern best practice

#### **Step 4: Add SQL Server with CDC**
```yaml
sqlserver:
  image: mcr.microsoft.com/mssql/server:2022-latest
  environment:
    MSSQL_AGENT_ENABLED: "true"  # Required for CDC!
    SA_PASSWORD: "YourStrong@Passw0rd"
```

**What we configured:**
1. Enable CDC on database
2. Enable CDC on specific table
3. Start SQL Server Agent (captures changes)

```sql
-- Enable CDC on database
EXEC sys.sp_cdc_enable_db;

-- Enable CDC on table
EXEC sys.sp_cdc_enable_table
    @source_schema = 'dbo',
    @source_name   = 'users',
    @role_name     = NULL;
```

**Key Learning:**
- CDC must be enabled at database AND table level
- SQL Server Agent must be running
- Without these, Debezium can't capture changes

#### **Step 5: Add Debezium Connect**
```yaml
debezium:
  image: debezium/connect:2.5
  environment:
    BOOTSTRAP_SERVERS: kafka:9092  # Connect to Kafka
```

**What Debezium does:**
1. Connects to SQL Server
2. Reads transaction log
3. Converts changes to Kafka messages
4. Sends to Kafka topics

#### **Step 6: Add Kafka UI**
```yaml
kafka-ui:
  image: provectuslabs/kafka-ui:latest
  ports:
    - "8080:8080"
  environment:
    KAFKA_CLUSTERS_0_BOOTSTRAPSERVERS: kafka:9092
    KAFKA_CLUSTERS_0_KAFKACONNECT_0_ADDRESS: http://debezium:8083
```

**Key Learning:**
- Kafka UI needs to know about both Kafka AND Debezium
- This makes the "Kafka Connect" tab appear

### **Phase 4: Troubleshooting (The Real Learning!)**

#### **Issue 1: SQL Server Healthcheck Failed**
**Problem:**
```yaml
healthcheck:
  test: /opt/mssql-tools/bin/sqlcmd ...  # ❌ Wrong path!
```

**Why it failed:**
- SQL Server 2022 moved tools to `/opt/mssql-tools18/bin/`
- Healthcheck kept failing
- Other services couldn't start (they depend on SQL Server being healthy)

**Solution:**
```yaml
healthcheck:
  test: /opt/mssql-tools18/bin/sqlcmd ...  # ✅ Correct path!
```

**Key Learning:**
- Always check tool paths for your specific version
- Healthchecks are important for service dependencies
- Read error logs carefully!

#### **Issue 2: Debezium Can't Connect to Kafka**
**Problem:**
```
Debezium logs: "Connection to localhost:9092 failed"
```

**Why it failed:**
```
Inside Docker:
- Debezium container tries "localhost:9092"
- "localhost" means "myself" to each container
- Debezium looks for Kafka on itself (wrong!)
```

**The Docker Network Concept:**
```
❌ Wrong:
Debezium → localhost:9092 → Looks at itself → No Kafka found

✅ Right:
Debezium → kafka:9092 → Looks at "kafka" container → Found!
```

**Solution:**
```yaml
kafka:
  environment:
    # For internal Docker communication:
    KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://kafka:9092
    # For external (your computer):
    PLAINTEXT_HOST://localhost:9094
```

**Key Learning:**
- Containers use container names, not "localhost"
- Kafka needs different listeners for internal vs external
- Network configuration is critical!

#### **Issue 3: Kafka Connect Tab Not Showing**
**Problem:**
- Kafka UI opened, but no "Kafka Connect" tab

**Why it failed:**
- Kafka UI didn't know about Debezium
- Configuration was missing

**Solution:**
```yaml
kafka-ui:
  environment:
    # Tell Kafka UI about Debezium:
    KAFKA_CLUSTERS_0_KAFKACONNECT_0_NAME: debezium
    KAFKA_CLUSTERS_0_KAFKACONNECT_0_ADDRESS: http://debezium:8083
```

**Key Learning:**
- Services need explicit configuration to discover each other
- Just running services isn't enough - they need to be connected

#### **Issue 4: Connector Creation Timeout**
**Problem:**
- Click "Create Connector" in UI
- Wait 90 seconds
- Get "400 Bad Request" or timeout error

**Why it happens:**
```
When you create a connector, Debezium:
1. Connects to SQL Server ✅
2. Validates CDC is enabled ✅
3. Reads transaction log metadata ⏱️ (slow!)
4. Checks all tables ⏱️ (slow!)
5. Validates Kafka connection ✅
6. Creates internal topics ⏱️ (slow!)

Total time: > 90 seconds = TIMEOUT!
```

**What we tried:**
1. ✅ Simplified connector config (removed transforms)
2. ✅ Changed snapshot mode to "schema_only"
3. ✅ Verified all services can communicate
4. ⏱️ Still times out (SQL Server validation is slow)

**Solutions that work:**
```yaml
# Option 1: Increase timeout in Debezium
debezium:
  environment:
    CONNECT_TASK_SHUTDOWN_GRACEFUL_TIMEOUT_MS: "180000"

# Option 2: Use REST API with longer timeout
curl -X POST http://localhost:8083/connectors \
  -H "Content-Type: application/json" \
  -d @connector.json \
  --max-time 180

# Option 3: Use simpler snapshot mode
{
  "snapshot.mode": "schema_only"  # Skip initial data load
}
```

**Key Learning:**
- Validation takes time, especially with CDC
- Default timeouts might not be enough
- Multiple ways to create connectors (UI, REST API, config files)

---

## 🔍 Common Issues and Solutions

### **Issue: "Port already in use"**
```bash
# Check what's using the port
netstat -ano | findstr :9092

# Stop the container using it
docker stop <container-name>
```

### **Issue: "Container keeps restarting"**
```bash
# Check logs
docker logs <container-name>

# Common causes:
# 1. Wrong environment variables
# 2. Missing dependencies
# 3. Port conflicts
```

### **Issue: "Can't connect to SQL Server"**
```bash
# Test connection
docker exec sqlserver /opt/mssql-tools18/bin/sqlcmd \
  -S localhost -U sa -P 'YourPassword' -Q "SELECT 1"

# Check if SQL Server Agent is running
docker exec sqlserver /opt/mssql-tools18/bin/sqlcmd \
  -S localhost -U sa -P 'YourPassword' \
  -Q "SELECT status_desc FROM sys.dm_server_services WHERE servicename LIKE '%Agent%'"
```

### **Issue: "CDC not working"**
```sql
-- Check if CDC is enabled on database
SELECT name, is_cdc_enabled 
FROM sys.databases 
WHERE name = 'YourDatabase';

-- Check if CDC is enabled on table
EXEC sys.sp_cdc_help_change_data_capture;

-- Check CDC jobs
EXEC msdb.dbo.sp_help_job @job_name = 'cdc.YourDatabase_capture';
```

---

## ✅ How to Verify Everything Works

### **Step 1: Check All Containers Running**
```bash
docker ps
```
Expected output:
```
kafka           Up    0.0.0.0:9092->9092/tcp
sqlserver       Up    0.0.0.0:1433->1433/tcp
kafka-debezium  Up    0.0.0.0:8083->8083/tcp
kafka-ui        Up    0.0.0.0:8080->8080/tcp
```

### **Step 2: Check Kafka UI**
1. Open http://localhost:8080
2. Should see:
   - Dashboard with cluster info
   - Brokers tab (1 broker)
   - Topics tab (system topics)
   - Kafka Connect tab (Debezium)

### **Step 3: Check Debezium**
```bash
# List connectors (should be empty initially)
curl http://localhost:8083/connectors

# Check Debezium is healthy
curl http://localhost:8083
# Should return: {"version":"3.6.1","commit":"..."}
```

### **Step 4: Check SQL Server CDC**
```sql
-- Connect to SQL Server
docker exec -it sqlserver /opt/mssql-tools18/bin/sqlcmd \
  -S localhost -U sa -P 'YourPassword' -No

-- Run these queries:
USE TestDB;
GO

-- Check CDC is enabled
SELECT name, is_cdc_enabled FROM sys.databases WHERE name = 'TestDB';
-- Should return: is_cdc_enabled = 1

-- Check CDC tables
EXEC sys.sp_cdc_help_change_data_capture;
-- Should show: dbo_users capture instance

-- Check CDC jobs are running
SELECT name, enabled FROM msdb.dbo.sysjobs WHERE name LIKE 'cdc%';
-- Should show: cdc.TestDB_capture (enabled = 1)
```

### **Step 5: Test End-to-End (After Connector Created)**
```sql
-- Insert test data
INSERT INTO dbo.users (name, email) 
VALUES ('Test User', 'test@example.com');
```

Then check Kafka UI:
1. Go to Topics tab
2. Look for topic: `sqlserver.dbo.users`
3. Click on it
4. See the message with your inserted data!

---

## 🎓 Key Learnings

### **1. Docker Networking**
```
✅ DO: Use container names (kafka:9092)
❌ DON'T: Use localhost inside containers

Why? Each container has its own "localhost"
```

### **2. Service Dependencies**
```
Order matters!
1. Kafka must start first
2. Then SQL Server
3. Then Debezium (needs both Kafka and SQL Server)
4. Then Kafka UI (needs Kafka and Debezium)
```

### **3. Healthchecks Are Important**
```yaml
healthcheck:
  test: ["CMD", "test-command"]
  interval: 10s
  timeout: 5s
  retries: 10
```
- Other services wait for healthy status
- Prevents startup race conditions
- Helps debug issues

### **4. CDC Requires Multiple Steps**
```
1. Enable CDC on database
2. Enable CDC on each table
3. Ensure SQL Server Agent is running
4. Wait for CDC jobs to initialize
5. Then Debezium can connect
```

### **5. Configuration Matters**
```
Small mistakes = Big problems:
- Wrong port number
- Wrong password
- Wrong path
- Missing environment variable

Always double-check configuration!
```

### **6. Logs Are Your Friend**
```bash
# Always check logs when something fails
docker logs <container-name>

# Follow logs in real-time
docker logs -f <container-name>

# Last 50 lines
docker logs --tail 50 <container-name>
```

### **7. Start Simple, Add Complexity**
```
✅ Good approach:
1. Get basic Kafka working
2. Add SQL Server
3. Add Debezium
4. Add UI
5. Configure connector

❌ Bad approach:
1. Set up everything at once
2. Nothing works
3. Don't know what's broken
```

---

## 🚀 If You're Starting Fresh

### **Recommended Order:**

#### **Day 1: Learn Kafka Basics**
1. Run simple Kafka setup
2. Create producer/consumer scripts
3. Send and receive messages
4. Understand topics and partitions

#### **Day 2: Add SQL Server**
1. Run SQL Server container
2. Create database and table
3. Enable CDC
4. Verify CDC is capturing changes

#### **Day 3: Connect with Debezium**
1. Add Debezium container
2. Configure network properly
3. Create simple connector
4. See changes flow to Kafka

#### **Day 4: Add Management Tools**
1. Add Kafka UI
2. Explore topics visually
3. Monitor connector status
4. Test end-to-end flow

### **Best Practices:**

1. **Use Docker Compose**
   - Easier to manage multiple services
   - Configuration in one file
   - Easy to start/stop everything

2. **Use Named Networks**
   ```yaml
   networks:
     kafka-network:
       driver: bridge
   ```
   - Better isolation
   - Easier debugging

3. **Use Volumes for Data**
   ```yaml
   volumes:
     sqlserver-data:/var/opt/mssql
   ```
   - Data persists across restarts
   - Don't lose your work!

4. **Document Everything**
   - Write down what you did
   - Note any issues and solutions
   - Future you will thank you!

5. **Test Incrementally**
   - Don't add everything at once
   - Test after each change
   - Easier to find problems

---

## 📚 Additional Resources

### **Understanding Kafka:**
- Topics = Categories for messages
- Partitions = Subdivisions of topics (for scaling)
- Producers = Send messages
- Consumers = Read messages
- Brokers = Kafka servers

### **Understanding CDC:**
- Transaction Log = Database's diary of all changes
- Capture Job = Reads transaction log
- Change Table = Stores captured changes
- Debezium = Reads change table, sends to Kafka

### **Kafka Connect Concepts:**
- Connector = Configuration for data source/sink
- Task = Worker that moves data
- Converter = Transforms data format
- Transform = Modifies data in-flight

---

## 🎯 Final Checklist

Before saying "it works":

- [ ] All containers running (`docker ps`)
- [ ] Kafka UI accessible (http://localhost:8080)
- [ ] Kafka Connect tab visible in UI
- [ ] SQL Server CDC enabled (check with query)
- [ ] SQL Server Agent running
- [ ] Debezium can connect to Kafka (check logs)
- [ ] Debezium can connect to SQL Server (check logs)
- [ ] Connector created successfully
- [ ] Test data inserted in SQL Server
- [ ] Change appears in Kafka topic
- [ ] Can view message in Kafka UI

---

## 💡 Remember

**Kafka CDC is powerful but complex. Don't get discouraged!**

- Everyone struggles with Docker networking at first
- Configuration issues are normal
- Logs will guide you
- Google is your friend
- Community forums are helpful

**The key is understanding each piece, then connecting them together.**

Good luck! 🚀