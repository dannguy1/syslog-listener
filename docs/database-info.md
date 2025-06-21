# Database Information

## Overview

This document describes the database schema and structure for the syslog listener system. The system connects to an existing PostgreSQL database at `192.168.10.14` and works with the following tables. **The system is fully compatible with External AI Analyzer databases and requires no migration.**

## Database Connection

- **Host**: 192.168.10.14
- **Database**: netmonitor_db
- **User**: netmonitor_user
- **Password**: netmonitor_password
- **Port**: 5432

## External AI Analyzer Compatibility

The syslog listener system is designed to work seamlessly with existing External AI Analyzer databases:

- ✅ **No Migration Required**: Works directly with existing External AI Analyzer databases
- ✅ **Schema Compatibility**: Uses the exact same table structure and field types
- ✅ **Data Preservation**: All existing data remains untouched
- ✅ **Seamless Integration**: New log entries are added to existing tables

### Field Mapping

The system maps syslog data to External AI Analyzer fields:

| Syslog Field | Database Field | Type | Notes |
|--------------|----------------|------|-------|
| Hostname | `hostname` | VARCHAR(255) | Device that generated the log |
| Program | `program` | VARCHAR(255) | Name of the generating program |
| PID | `pid` | INTEGER | Process ID from syslog message |
| Priority | `priority` | INTEGER | Calculated priority (facility * 8 + severity) |
| Facility | `facility` | INTEGER | Syslog facility number (0-23) |
| Severity | `severity` | INTEGER | Syslog severity level (0-7) |
| Message | `message` | TEXT | The actual log content |
| Raw Message | `raw_message` | TEXT | Original unparsed log message |

## Database Schema

### Devices Table
```sql
CREATE TABLE devices (
    id INTEGER PRIMARY KEY,
    name VARCHAR(128) NOT NULL,
    ip_address VARCHAR(45) NOT NULL UNIQUE,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### Log Entries Table
```sql
CREATE TABLE log_entries (
    id INTEGER PRIMARY KEY,
    device_id INTEGER NOT NULL,
    device_ip VARCHAR(45) NOT NULL,
    timestamp TIMESTAMP NOT NULL,
    log_level VARCHAR(50),
    process_name VARCHAR(128),
    message TEXT NOT NULL,
    raw_message TEXT,
    structured_data JSON,
    pushed_to_ai BOOLEAN DEFAULT FALSE,
    pushed_at TIMESTAMP,
    push_attempts INTEGER DEFAULT 0,
    last_push_error TEXT,
    FOREIGN KEY (device_id) REFERENCES devices(id)
);

-- Indexes for efficient querying
CREATE INDEX ix_log_entries_device_id ON log_entries(device_id);
CREATE INDEX ix_log_entries_device_ip ON log_entries(device_ip);
CREATE INDEX ix_log_entries_log_level ON log_entries(log_level);
CREATE INDEX ix_log_entries_process_name ON log_entries(process_name);
CREATE INDEX ix_log_entries_pushed_to_ai ON log_entries(pushed_to_ai);
CREATE INDEX ix_log_entries_timestamp ON log_entries(timestamp);
```

### Log Anomalies Table (Referenced by External System)
```sql
CREATE TABLE log_anomalies (
    id INTEGER PRIMARY KEY,
    log_entry_id INTEGER,
    -- Additional fields for anomaly detection
    FOREIGN KEY (log_entry_id) REFERENCES log_entries(id)
);
```

## Log Structure

### Log Entry Fields
1. **id**: Unique identifier for the log entry (auto-increment)
2. **device_id**: Reference to the device that generated the log (foreign key to devices.id)
3. **device_ip**: IP address of the device that generated the log (VARCHAR(45))
4. **timestamp**: When the log was generated (UTC timestamp)
5. **log_level**: Severity level of the log (VARCHAR(50))
6. **process_name**: Name of the process that generated the log (VARCHAR(128))
7. **message**: The actual log message content (TEXT)
8. **raw_message**: Original unparsed syslog message (TEXT)
9. **structured_data**: Additional JSON data extracted from the log (JSON)
10. **pushed_to_ai**: Whether the log has been sent to AI analysis (BOOLEAN, default FALSE)
11. **pushed_at**: When the log was last sent to AI analysis (TIMESTAMP)
12. **push_attempts**: Number of attempts to push to AI (INTEGER, default 0)
13. **last_push_error**: Last error message from AI push attempt (TEXT)

### Device Fields
1. **id**: Unique identifier for the device (auto-increment)
2. **name**: Human-readable name for the device (VARCHAR(128))
3. **ip_address**: IP address of the device (VARCHAR(45), unique)
4. **description**: Optional description of the device (TEXT)
5. **created_at**: When the device record was created (TIMESTAMP)
6. **updated_at**: When the device record was last updated (TIMESTAMP)

## Log Levels

The system supports standard syslog severity levels as strings:
- **emergency**: System is unusable
- **alert**: Action must be taken immediately
- **critical**: Critical conditions
- **error**: Error conditions
- **warning**: Warning conditions
- **notice**: Normal but significant condition
- **info**: Informational messages
- **debug**: Debug-level messages

## Syslog Message Parsing

The system parses syslog messages according to RFC 3164/5424 standards:

### Supported Formats
1. **Standard Syslog**: `<PRI>TIMESTAMP HOSTNAME PROGRAM[PID]: MESSAGE`
2. **RFC 5424**: Extended format with structured data
3. **Fallback**: Basic parsing for non-standard formats

### Parsed Fields
- **Priority**: Extracted from `<PRI>` format and converted to log_level
- **Timestamp**: Parsed from message header
- **Hostname**: Extracted from message (stored as device_ip)
- **Program**: Name of the generating program (stored as process_name)
- **Message**: The actual log content

### Priority Calculation
The parser correctly extracts facility and severity from syslog priority:

```python
# Extract facility from priority (bits 3-7)
facility = (priority >> 3) & 0x1F

# Extract severity from priority (last 3 bits)
severity = priority & 0x07

# Calculate priority
priority = facility * 8 + severity
```

## Database Operations

### Device Management
- **Auto-creation**: Devices are automatically created when first encountered
- **IP-based identification**: Devices are identified by their IP address
- **Name generation**: Default names are generated as "Device-{IP}" if not provided

### Log Entry Storage
- **Automatic parsing**: Raw syslog messages are parsed into structured fields
- **Device association**: Log entries are automatically associated with device records
- **Error handling**: Failed insertions are logged with error details

### Indexes and Performance
- **Primary indexes**: Optimized for device_id and timestamp queries
- **Secondary indexes**: Support filtering by log_level, process_name, and device_ip
- **AI integration**: Indexes support pushed_to_ai status queries

## Integration with External Systems

### External AI Analyzer
- The `log_entries` table is designed to work with external AI analysis systems
- The `pushed_to_ai`, `pushed_at`, `push_attempts`, and `last_push_error` fields support AI integration
- The `log_anomalies` table can store results from AI analysis

### Query Examples
```sql
-- Get recent logs
SELECT * FROM log_entries 
WHERE timestamp > NOW() - INTERVAL '5 minutes' 
ORDER BY timestamp DESC;

-- Get logs by severity
SELECT * FROM log_entries 
WHERE log_level IN ('error', 'critical', 'emergency') 
ORDER BY timestamp DESC;

-- Get logs by device
SELECT * FROM log_entries 
WHERE device_ip = '192.168.1.100' 
ORDER BY timestamp DESC 
LIMIT 100;

-- Get logs that haven't been pushed to AI
SELECT * FROM log_entries 
WHERE pushed_to_ai = FALSE 
ORDER BY timestamp ASC;
```

## Installation and Setup

### Simple Installation
1. Configure environment variables in `.env`
2. Run `python src/main.py`
3. System automatically connects to existing database or creates new one

### No Migration Process
- No database migration scripts needed
- No data backup/restore required
- No schema changes performed
- Works immediately with existing External AI Analyzer installations

## Maintenance and Monitoring

### Key Metrics
- Log processing rate
- Database connection status
- Error rates in log parsing
- AI push success/failure rates

### Performance Considerations
- Use appropriate indexes for query optimization
- Monitor database connection pool usage
- Consider log rotation for large deployments
- Monitor disk usage for log storage

### Backup and Recovery
- Regular backups of the `log_entries` and `devices` tables
- Consider archiving old log entries for performance
- Monitor foreign key constraints for data integrity

## Troubleshooting

### Common Issues
1. **Database Connection Failed**: Check database credentials and connectivity
2. **Parsing Errors**: Verify syslog message format compatibility
3. **Field Type Mismatches**: Ensure database schema matches External AI Analyzer

### Debug Steps
1. Run compatibility test script: `python scripts/test_compatibility.py`
2. Check database schema manually
3. Review application logs for errors
4. Verify environment configuration