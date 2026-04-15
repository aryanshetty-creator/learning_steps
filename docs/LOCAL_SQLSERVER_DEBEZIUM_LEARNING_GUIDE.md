# Local SQL Server to Debezium to Kafka Learning Guide

## Goal

Connect a local Windows SQL Server instance to Debezium running in Docker, stream CDC events into Kafka, and verify them in Kafka UI.

This guide captures:

- the setup that finally worked
- the errors we hit
- how we diagnosed them
- how to fix the same problems next time
- the commands and SQL we used

## Final Working Setup

### Architecture

```text
Local SQL Server on Windows
  Database: CDC_Demo
  Table: dbo.Users
  TCP Port: 14330
        |
        | host.docker.internal:14330
        v
Debezium in Docker
        |
        v
Kafka in Docker
        |
        v
Kafka UI at http://localhost:8080
```

### Final Connector Values

The working connector values are:

```properties
database.hostname=host.docker.internal
database.port=14330
database.user=sa
database.password=YourStrong@Passw0rd
database.names=CDC_Demo
topic.prefix=local-sqlserver
table.include.list=dbo.Users
snapshot.mode=initial
snapshot.locking.mode=none
```

Current file:

- `configs/sqlserver-connector.properties`

## Why This Was Tricky

SSMS was able to connect to the local SQL Server, but Debezium still failed.

The main reason:

- SSMS was initially using `Shared memory`
- Debezium cannot use `Shared memory`
- Debezium needs a real TCP port

So a connection that works in SSMS is not enough by itself. The connection must also work over TCP.

## Steps To Make It Work

### 1. Make sure SQL Server Authentication is enabled

Open SSMS with a working Windows-auth session and run:

```sql
SELECT SERVERPROPERTY('IsIntegratedSecurityOnly') AS windows_only;
GO

SELECT name, is_disabled
FROM sys.sql_logins
WHERE name = 'sa';
GO
```

What you want:

- `windows_only = 0`
- `sa` exists
- `is_disabled = 0`

If needed:

```sql
ALTER LOGIN sa ENABLE;
GO
ALTER LOGIN sa WITH PASSWORD = 'YourStrong@Passw0rd';
GO
```

### 2. Enable TCP/IP for the local SQL Server

In `SQL Server Configuration Manager`:

1. Go to `SQL Server Network Configuration`
2. Open `Protocols for MSSQLSERVER`
3. Make sure `TCP/IP` is enabled
4. Open `TCP/IP > Properties > IP Addresses`
5. In `IPAll` set:

```text
TCP Dynamic Ports =
TCP Port = 14330
```

Do not use `1433` here in this setup, because Docker SQL Server was already published on `1433`.

Avoid `3389` too, because that is commonly used for Remote Desktop and causes confusion/conflicts.

### 3. Restart local SQL Server

Restart:

```text
SQL Server (MSSQLSERVER)
```

You can do it from:

- `SQL Server Configuration Manager`
- or Windows `Services`

### 4. Verify TCP login from SSMS

Try a fresh SQL-auth connection using:

```text
Server Name: localhost,14330
Authentication: SQL Server Authentication
User Name: sa
Password: YourStrong@Passw0rd
Database Name: CDC_Demo
Encrypt: Optional
Trust Server Certificate: checked
```

If `localhost,14330` fails, also test:

```text
127.0.0.1,14330
```

### 5. Prepare the database and table

The local database used for the successful test was:

- database: `CDC_Demo`
- table: `dbo.Users`

To check whether the database exists:

```sql
SELECT name
FROM sys.databases
WHERE name = 'CDC_Demo';
GO
```

To inspect the table:

```sql
USE CDC_Demo;
GO
sp_help 'dbo.Users';
GO
```

### 6. Enable CDC

Enable CDC on the database:

```sql
USE CDC_Demo;
GO
EXEC sys.sp_cdc_enable_db;
GO
```

Enable CDC on the table:

```sql
USE CDC_Demo;
GO
EXEC sys.sp_cdc_enable_table
    @source_schema = 'dbo',
    @source_name = 'Users',
    @role_name = NULL;
GO
```

### 7. Configure Debezium to target local SQL Server

Working properties file:

```properties
name=sqlserver-source-connector
connector.class=io.debezium.connector.sqlserver.SqlServerConnector
tasks.max=1
database.hostname=host.docker.internal
database.port=14330
database.user=sa
database.password=YourStrong@Passw0rd
database.names=CDC_Demo
database.encrypt=false
database.trustServerCertificate=true
topic.prefix=local-sqlserver
table.include.list=dbo.Users
snapshot.mode=initial
snapshot.locking.mode=none
include.schema.changes=false
schema.history.internal.kafka.bootstrap.servers=kafka:9092
schema.history.internal.kafka.topic=schema-changes.local-sqlserver
```

### 8. Start or restart Debezium

From the repo root:

```powershell
docker compose up -d debezium
```

Check whether the REST API is alive:

```powershell
Invoke-RestMethod -Uri http://localhost:8083/
```

Check connector list:

```powershell
Invoke-RestMethod -Uri http://localhost:8083/connectors
```

Check status:

```powershell
Invoke-RestMethod -Uri http://localhost:8083/connectors/sqlserver-source-connector/status
```

### 9. Insert test data

We first tried:

```sql
INSERT INTO dbo.Users DEFAULT VALUES;
GO
```

That failed because `UserID` does not allow nulls.

The working insert was:

```sql
USE CDC_Demo;
GO

INSERT INTO dbo.Users (UserID, Name)
VALUES (1001, 'test user');
GO
```

### 10. Verify in Kafka UI

Open:

```text
http://localhost:8080
```

Look for the topic:

```text
local-sqlserver.CDC_Demo.dbo.Users
```

The successful message included:

```json
{
  "before": null,
  "after": {
    "UserID": 1001,
    "Name": "test user"
  }
}
```

## Errors We Faced And How We Solved Them

### Error 1: Debezium pointed at the wrong port

#### Symptom

Connector configs had different ports like:

- `3389`
- `51124`
- `1433`

This caused confusion and wrong targets.

#### Why it happened

- `1433` was already mapped to the Docker SQL Server container
- `3389` is commonly Remote Desktop, not a safe SQL choice here
- different files had drifted apart

#### Fix

Pick one real local SQL TCP port and use it consistently:

```text
14330
```

Update all connector config files to match.

#### What to check next time

- Is the port really the local SQL Server port?
- Is Docker already using that host port?
- Do all connector config files match?

### Error 2: Debezium connected to Docker SQL Server instead of local SQL Server

#### Symptom

Debezium failed with:

```text
Cannot open database "CDC_Demo" requested by the login.
```

#### Why it happened

Debezium used:

```text
host.docker.internal:1433
```

But the host port `1433` was serving the Docker SQL Server container, not the local Windows SQL instance we wanted.

#### Fix

Move the local SQL Server to a different TCP port:

```text
14330
```

Then point Debezium to:

```text
host.docker.internal:14330
```

#### What to check next time

- Which service owns the port you gave Debezium?
- Is the local DB really on that port?
- Is Docker publishing a conflicting service on the same port?

### Error 3: SSMS worked but Debezium still failed

#### Symptom

SSMS could connect, but Debezium still could not.

#### Why it happened

SSMS was using:

```text
Shared memory
```

Debezium requires:

```text
TCP/IP
```

#### Fix

Enable TCP/IP and connect with:

```text
localhost,14330
```

If SQL-auth over `localhost,14330` works in SSMS, Debezium usually has a real chance too.

#### What to check next time

Run:

```sql
SELECT
  CONNECTIONPROPERTY('local_net_address') AS local_net_address,
  CONNECTIONPROPERTY('local_tcp_port') AS local_tcp_port,
  CONNECTIONPROPERTY('net_transport') AS net_transport;
```

If `net_transport` is `Shared memory`, that is not enough for Debezium.

### Error 4: `sa` login failed

#### Symptom

SSMS popup:

```text
Login failed for user 'sa'. (Microsoft SQL Server, Error: 18456)
```

#### Why it happened

The SQL-auth path was not yet fully valid, even though Windows-auth worked.

#### Fix

Run in a working Windows-auth session:

```sql
ALTER LOGIN sa ENABLE;
GO
ALTER LOGIN sa WITH PASSWORD = 'YourStrong@Passw0rd';
GO
```

Verify:

```sql
SELECT SERVERPROPERTY('IsIntegratedSecurityOnly') AS windows_only;
GO

SELECT name, is_disabled
FROM sys.sql_logins
WHERE name = 'sa';
GO
```

Desired result:

- `windows_only = 0`
- `is_disabled = 0`

#### What to check next time

- Is mixed mode enabled?
- Is `sa` enabled?
- Are you sure you are testing the local SQL Server, not the container?
- Did you restart SQL Server after auth mode or TCP changes?

### Error 5: Debezium container logs were not helpful

#### Symptom

Normal `docker logs` output mostly showed:

```text
Could not read configuration file ... connect-log4j.properties
```

#### Why it happened

The image expected `connect-log4j.properties`, but only `log4j.properties` was available in the path we inspected.

#### Fix

Run a one-off debug container with explicit log4j configuration:

```powershell
docker compose run --rm --entrypoint bash debezium -lc "export KAFKA_LOG4J_OPTS='-Dlog4j.configuration=file:/kafka/config/log4j.properties'; /kafka/bin/connect-standalone.sh /configs/connect-standalone.properties /configs/sqlserver-connector.properties 2>&1"
```

This exposed the real connector validation errors.

#### What to check next time

- If normal logs are vague, run the connector manually with explicit logging
- Read the SQLServerException carefully; it usually points to the real cause

### Error 6: `DEFAULT VALUES` insert failed

#### Symptom

SQL error:

```text
Cannot insert the value NULL into column 'UserID'
```

#### Why it happened

The table had:

- `UserID int not null`
- no identity column

#### Fix

Insert the required value explicitly:

```sql
INSERT INTO dbo.Users (UserID, Name)
VALUES (1001, 'test user');
GO
```

#### What to check next time

Use:

```sql
sp_help 'dbo.Users';
GO
```

Or:

```sql
SELECT COLUMN_NAME, IS_NULLABLE, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'dbo'
  AND TABLE_NAME = 'Users'
ORDER BY ORDINAL_POSITION;
GO
```

## Quick Troubleshooting Checklist

If the same kind of setup fails later, check these in order:

1. Can SSMS connect to local SQL using `localhost,<tcp-port>` with SQL auth?
2. Is the SQL instance using TCP, not just shared memory?
3. Is mixed mode enabled?
4. Is `sa` enabled and using the expected password?
5. Does the database really exist on that instance?
6. Is CDC enabled on the database?
7. Is CDC enabled on the table?
8. Is Debezium pointing to `host.docker.internal:<local-sql-port>`?
9. Is that host port actually owned by the local SQL Server, not Docker SQL Server?
10. Is the connector status `RUNNING`?
11. Does Kafka UI show the expected topic?

## Useful Commands

### Docker

```powershell
docker compose up -d
docker compose up -d debezium
docker ps -a
docker logs kafka-debezium-1 --tail 200
```

### Debezium REST API

```powershell
Invoke-RestMethod -Uri http://localhost:8083/
Invoke-RestMethod -Uri http://localhost:8083/connectors
Invoke-RestMethod -Uri http://localhost:8083/connectors/sqlserver-source-connector/status
```

### SQL checks

```sql
SELECT SERVERPROPERTY('IsIntegratedSecurityOnly') AS windows_only;
GO

SELECT name, is_disabled
FROM sys.sql_logins
WHERE name = 'sa';
GO

SELECT name
FROM sys.databases
WHERE name = 'CDC_Demo';
GO

USE CDC_Demo;
GO
EXEC sys.sp_cdc_help_change_data_capture;
GO

SELECT TOP 10 *
FROM cdc.dbo_Users_CT
ORDER BY __$start_lsn DESC;
GO
```

## Final Proof Of Success

The final successful path was:

1. local SQL Server accepted SQL-auth on `localhost,14330`
2. Debezium connected to `host.docker.internal:14330`
3. connector status became `RUNNING`
4. insert into `CDC_Demo.dbo.Users` succeeded
5. Kafka UI showed the topic:

```text
local-sqlserver.CDC_Demo.dbo.Users
```

6. the new row appeared in Kafka as a CDC event

That is the repeatable reference flow for next time.
