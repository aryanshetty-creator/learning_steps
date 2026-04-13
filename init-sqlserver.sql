-- Initialize SQL Server with CDC enabled
-- This script runs automatically when SQL Server starts

USE master;
GO

-- Enable CDC on the master database (or create a new database)
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'TestDB')
BEGIN
    CREATE DATABASE TestDB;
END
GO

USE TestDB;
GO

-- Enable CDC on the database
IF NOT EXISTS (SELECT * FROM sys.change_tracking_databases WHERE database_id = DB_ID())
BEGIN
    EXEC sys.sp_cdc_enable_db;
    PRINT 'CDC enabled on TestDB database';
END
GO

-- Create a sample users table
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'users')
BEGIN
    CREATE TABLE dbo.users (
        id INT IDENTITY(1,1) PRIMARY KEY,
        name NVARCHAR(100) NOT NULL,
        email NVARCHAR(255) NOT NULL,
        created_at DATETIME2 DEFAULT GETDATE(),
        updated_at DATETIME2 DEFAULT GETDATE()
    );
    PRINT 'Users table created';
END
GO

-- Enable CDC on the users table
IF NOT EXISTS (SELECT * FROM cdc.change_tables WHERE source_object_id = OBJECT_ID('dbo.users'))
BEGIN
    EXEC sys.sp_cdc_enable_table
        @source_schema = 'dbo',
        @source_name   = 'users',
        @role_name     = NULL;
    PRINT 'CDC enabled on users table';
END
GO

-- Insert sample data
IF NOT EXISTS (SELECT * FROM dbo.users)
BEGIN
    INSERT INTO dbo.users (name, email) VALUES 
        ('John Doe', 'john@example.com'),
        ('Jane Smith', 'jane@example.com'),
        ('Bob Johnson', 'bob@example.com');
    PRINT 'Sample data inserted';
END
GO

PRINT 'SQL Server initialization completed successfully!';