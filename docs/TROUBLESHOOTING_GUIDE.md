# Kafka-Debezium Troubleshooting Guide

## 🔴 The Problem We Faced

### Issue: "Request timed out. The worker is currently ensuring membership in the cluster"

When trying to create the Debezium connector, it would timeout after 90 seconds with this error message.

### Why It Happened

Debezium Connect was running in **Distributed Mode** by default. In this mode:
- It tries to coordinate with other workers in a cluster
- With only ONE worker, it gets stuck in an endless "rebalancing" loop
- The rebalancing process takes longer than the 90-second timeout
- Connector creation fails every time

## ✅ The Solution

**Switch from Distributed Mode to Standalone Mode**

This completely bypasses the cluster coordination issue.

## 🔧 How We Fixed It

### Step 1: Created Standalone Configuration Files

**File: `configs/connect-standalone.properties`**
```properties
bootstrap.servers=kafka:9092
key.converter=org.apache.kafka.connect.json.JsonConverter
value.converter=org.apache.kafka.connect.json.JsonConverter
key.converter.schemas.enable=false
value.converter.schemas.enable=false
offset.storage.file.filename=/tmp/connect.offsets
offset.flush.interval.ms=10000
plugin.path=/kafka/connect
```

**File: `configs/sqlserver-connector.properties`**
```properties
name=sqlserver-source-connector
connector.class=io.debezium.connector.sqlserver.SqlServerConnector
tasks.max=1
database.hostname=sqlserver
database.port=1433
database.user=sa
database.password=YourStrong@Passw0rd
database.names=TestDB
database.encrypt=false
database.trustServerCertificate=true
topic.prefix=sqlserver
table.include.list=dbo.users
snapshot.mode=initial
snapshot.locking.mode=none
include.schema.changes=false
schema.history.internal.kafka.bootstrap.servers=kafka:9092
schema.history.internal.kafka.topic=schema-changes.sqlserver
```

### Step 2: Updated docker-compose.yml

Changed the Debezium service to run in standalone mode:

```yaml
debezium:
  image: debezium/connect:3.0.0.Final
  ports:
    - "8083:8083"
  depends_on:
    - kafka
  volumes:
    - ./configs:/configs
  command: >
    bash -c "
    /kafka/bin/connect-standalone.sh
    /configs/connect-standalone.properties
    /configs/sqlserver-connector.properties
    "
  networks:
    - kafka-network
```

### Step 3: Restart Debezium

```powershell
docker-compose up -d debezium
```

### Result: ✅ WORKED IMMEDIATELY!

- No timeout errors
- Connector started successfully
- Data captured and streamed to Kafka
- 3 messages appeared in the topic instantly

---

## 📊 Standalone vs Distributed Mode

### Distributed Mode (Default)

**What It Is:**
- Multiple Kafka Connect workers form a cluster
- They coordinate and share connector tasks
- Requires cluster membership and rebalancing

**Advantages:**
- ✅ High availability - if one worker fails, others take over
- ✅ Load balancing - tasks distributed across workers
- ✅ Scalability - add more workers to handle more load
- ✅ Fault tolerance - automatic failover

**Disadvantages:**
- ❌ Complex setup and coordination
- ❌ Requires multiple workers for best performance
- ❌ Rebalancing can cause delays
- ❌ With single worker, gets stuck in rebalancing loop (our issue!)
- ❌ More resource intensive

**Best For:**
- Production environments
- High-volume data pipelines
- When you need fault tolerance
- Multi-server deployments

---

### Standalone Mode

**What It Is:**
- Single Kafka Connect worker runs independently
- No cluster coordination needed
- Simpler, direct execution

**Advantages:**
- ✅ Simple setup - no cluster coordination
- ✅ Fast startup - no rebalancing delays
- ✅ Perfect for single-server setups
- ✅ Lower resource usage
- ✅ Easier to debug and troubleshoot
- ✅ Great for development and testing

**Disadvantages:**
- ❌ No high availability - if it fails, CDC stops
- ❌ No automatic failover
- ❌ Can't scale horizontally
- ❌ Single point of failure

**Best For:**
- Development and testing
- Single-server deployments
- Low to medium data volumes
- When simplicity is more important than HA

---

## 🔄 Quick Comparison Table

| Feature | Distributed Mode | Standalone Mode |
|---------|-----------------|-----------------|
| **Setup Complexity** | High | Low |
| **Startup Time** | Slow (rebalancing) | Fast |
| **High Availability** | Yes | No |
| **Scalability** | Horizontal | Vertical only |
| **Resource Usage** | Higher | Lower |
| **Fault Tolerance** | Yes | No |
| **Best For** | Production | Dev/Test |
| **Workers Needed** | Multiple (ideally) | One |
| **Configuration** | Environment variables | Property files |

---

## 🚨 How to Resolve This Issue Next Time

### If You Face the Same Timeout Error:

**Option 1: Switch to Standalone Mode (Recommended for Single Server)**

1. Create the two config files shown above
2. Update docker-compose.yml to use standalone command
3. Restart: `docker-compose up -d debezium`

**Option 2: Fix Distributed Mode (If You Need HA)**

Add these to docker-compose.yml environment:
```yaml
CONNECT_CONFIG_STORAGE_REPLICATION_FACTOR: "1"
CONNECT_OFFSET_STORAGE_REPLICATION_FACTOR: "1"
CONNECT_STATUS_STORAGE_REPLICATION_FACTOR: "1"
CONNECT_REBALANCE_TIMEOUT_MS: "300000"
```

**Option 3: Add More Workers**

Distributed mode works better with 2+ workers:
```yaml
debezium-1:
  # ... config ...
  
debezium-2:
  # ... same config, different container name ...
```

---

## 🎯 When to Use Which Mode?

### Use Standalone Mode When:
- ✅ Running on a single server
- ✅ Development or testing environment
- ✅ Low to medium data volume
- ✅ Simplicity is priority
- ✅ You're getting timeout/rebalancing errors

### Use Distributed Mode When:
- ✅ Production environment
- ✅ Need high availability
- ✅ Multiple servers available
- ✅ High data volume
- ✅ Need fault tolerance

---

## 📝 Key Takeaways

1. **The Problem**: Distributed mode with single worker = rebalancing timeout
2. **The Solution**: Standalone mode = no cluster coordination needed
3. **The Result**: Connector works immediately, CDC streaming successfully
4. **The Lesson**: Choose the right mode for your deployment scenario

---

## ✅ Verification Commands

Check if connector is working:
```powershell
# List topics (should see sqlserver.TestDB.dbo.users)
docker exec kafka /opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --list

# Check Debezium logs
docker logs kafka-debezium-1 --tail 50

# Or use Kafka UI (easier!)
# Open: http://localhost:8080
# Go to: Topics > sqlserver.TestDB.dbo.users > Messages
```

---

## 🔗 Useful Resources

- Debezium Documentation: https://debezium.io/documentation/
- Kafka Connect Modes: https://kafka.apache.org/documentation/#connect
- SQL Server CDC: https://debezium.io/documentation/reference/connectors/sqlserver.html

---

**Date Resolved:** April 14, 2026  
**Solution:** Switched from Distributed to Standalone Mode  
**Status:** ✅ Working perfectly!
