# External AI Analyzer Module

## Overview

The External AI Analyzer module is designed to read logs from and add anomaly records to the Log Monitor System's database. This document provides comprehensive details about the database schema, log structure, and anomaly records based on the actual implementation.

## Database Schema

### Devices Table
```sql
CREATE TABLE devices (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name VARCHAR(128) NOT NULL,
    ip_address VARCHAR(45) NOT NULL UNIQUE,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for efficient querying
CREATE INDEX idx_devices_ip_address ON devices(ip_address);
```

### Log Entries Table
```sql
CREATE TABLE log_entries (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
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
CREATE INDEX idx_log_entries_device_id ON log_entries(device_id);
CREATE INDEX idx_log_entries_device_ip ON log_entries(device_ip);
CREATE INDEX idx_log_entries_timestamp ON log_entries(timestamp);
CREATE INDEX idx_log_entries_log_level ON log_entries(log_level);
CREATE INDEX idx_log_entries_process_name ON log_entries(process_name);
CREATE INDEX idx_log_entries_pushed_to_ai ON log_entries(pushed_to_ai);
```

### Anomaly Records Table
```sql
CREATE TABLE anomaly_records (
    id SERIAL PRIMARY KEY,
    log_entry_id INTEGER REFERENCES log_entries(id),
    device_id INTEGER NOT NULL,
    timestamp TIMESTAMP NOT NULL,
    anomaly_type VARCHAR(50) NOT NULL,
    severity INTEGER NOT NULL,
    confidence FLOAT NOT NULL,
    description TEXT,
    metadata JSONB,
    status VARCHAR(20) DEFAULT 'new',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP,
    FOREIGN KEY (device_id) REFERENCES devices(id)
);

-- Indexes for efficient querying
CREATE INDEX idx_anomaly_records_device_id ON anomaly_records(device_id);
CREATE INDEX idx_anomaly_records_timestamp ON anomaly_records(timestamp);
CREATE INDEX idx_anomaly_records_anomaly_type ON anomaly_records(anomaly_type);
CREATE INDEX idx_anomaly_records_severity ON anomaly_records(severity);
CREATE INDEX idx_anomaly_records_status ON anomaly_records(status);
```

### Anomaly Patterns Table
```sql
CREATE TABLE anomaly_patterns (
    id SERIAL PRIMARY KEY,
    pattern_name VARCHAR(100) NOT NULL,
    pattern_type VARCHAR(50) NOT NULL,
    pattern_definition JSONB NOT NULL,
    severity INTEGER NOT NULL,
    description TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP
);

-- Indexes for efficient querying
CREATE INDEX idx_anomaly_patterns_pattern_type ON anomaly_patterns(pattern_type);
CREATE INDEX idx_anomaly_patterns_is_active ON anomaly_patterns(is_active);
```

## Log Structure

### Log Entry Fields
1. **id**: Unique identifier for the log entry (auto-increment)
2. **device_id**: Reference to the device that generated the log (foreign key to devices.id)
3. **device_ip**: IP address of the device that generated the log (VARCHAR(45))
4. **timestamp**: When the log was generated (UTC timestamp)
5. **log_level**: Severity level of the log as string (VARCHAR(50))
6. **process_name**: Name of the program that generated the log (VARCHAR(128))
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

### Log Levels
The system uses string-based log levels instead of numeric severity:
- **emergency**: System is unusable
- **alert**: Action must be taken immediately
- **critical**: Critical conditions
- **error**: Error conditions
- **warning**: Warning conditions
- **notice**: Normal but significant condition
- **info**: Informational messages
- **debug**: Debug-level messages

## Anomaly Records

### Anomaly Record Fields
1. **id**: Unique identifier for the anomaly record
2. **log_entry_id**: Reference to the associated log entry
3. **device_id**: Reference to the device where the anomaly was detected
4. **timestamp**: When the anomaly was detected (UTC)
5. **anomaly_type**: Type of anomaly detected
6. **severity**: Severity level of the anomaly (0-7)
7. **confidence**: Confidence score of the detection (0.0-1.0)
8. **description**: Human-readable description of the anomaly
9. **metadata**: Additional JSON data about the anomaly
10. **status**: Current status of the anomaly (new, investigating, resolved, etc.)
11. **created_at**: When the anomaly was recorded
12. **updated_at**: When the anomaly record was last updated

### Anomaly Types
1. **pattern_match**: Matches a known anomaly pattern
2. **statistical_anomaly**: Deviates from normal statistical patterns
3. **sequence_anomaly**: Unusual sequence of events
4. **frequency_anomaly**: Unusual frequency of events
5. **correlation_anomaly**: Unusual correlation between events
6. **custom_anomaly**: Custom anomaly type defined by patterns

### Anomaly Status Values
1. **new**: Newly detected anomaly
2. **investigating**: Under investigation
3. **resolved**: Issue has been resolved
4. **false_positive**: Not a real anomaly
5. **ignored**: Intentionally ignored
6. **escalated**: Escalated to higher priority

## Integration Guidelines

### Database Connection
```python
DATABASE_URL = "postgresql://netmonitor_user:netmonitor_password@<db_server>:5432/netmonitor_db"
```

### Reading Logs
1. Query logs within a time range:
```sql
SELECT * FROM log_entries 
WHERE timestamp BETWEEN :start_time AND :end_time 
ORDER BY timestamp DESC;
```

2. Query logs by device:
```sql
SELECT * FROM log_entries 
WHERE device_id = :device_id 
ORDER BY timestamp DESC;
```

3. Query logs by log level:
```sql
SELECT * FROM log_entries 
WHERE log_level IN ('error', 'critical', 'emergency') 
ORDER BY timestamp DESC;
```

4. Query logs that haven't been pushed to AI:
```sql
SELECT * FROM log_entries 
WHERE pushed_to_ai = FALSE 
ORDER BY timestamp DESC;
```

### Adding Anomaly Records
1. Basic anomaly record:
```sql
INSERT INTO anomaly_records (
    log_entry_id, device_id, timestamp, anomaly_type,
    severity, confidence, description, metadata
) VALUES (
    :log_entry_id, :device_id, :timestamp, :anomaly_type,
    :severity, :confidence, :description, :metadata
);
```

2. Update anomaly status:
```sql
UPDATE anomaly_records 
SET status = :new_status, updated_at = CURRENT_TIMESTAMP 
WHERE id = :anomaly_id;
```

## Best Practices

### Log Processing
1. Process logs in chronological order
2. Use batch processing for efficiency
3. Implement proper error handling
4. Log all processing activities
5. Monitor processing performance

### Anomaly Detection
1. Use appropriate confidence thresholds
2. Implement rate limiting for anomaly creation
3. Avoid duplicate anomaly records
4. Group related anomalies
5. Maintain anomaly history

### Performance Considerations
1. Use appropriate indexes
2. Implement connection pooling
3. Use batch operations when possible
4. Monitor query performance
5. Implement caching where appropriate

### Security
1. Use secure database connections
2. Implement proper access controls
3. Encrypt sensitive data
4. Monitor access patterns
5. Maintain audit logs

## Example Implementation

### Python Example
```python
from sqlalchemy import create_engine, text
from datetime import datetime, timedelta
import json

class ExternalAIAnalyzer:
    def __init__(self, db_url):
        self.engine = create_engine(db_url)
        
    def get_recent_logs(self, minutes=5):
        """Get logs from the last N minutes"""
        with self.engine.connect() as conn:
            query = text("""
                SELECT * FROM log_entries 
                WHERE timestamp > :start_time 
                ORDER BY timestamp DESC
            """)
            result = conn.execute(
                query, 
                {"start_time": datetime.utcnow() - timedelta(minutes=minutes)}
            )
            return result.fetchall()
            
    def get_unprocessed_logs(self):
        """Get logs that haven't been pushed to AI"""
        with self.engine.connect() as conn:
            query = text("""
                SELECT * FROM log_entries 
                WHERE pushed_to_ai = FALSE 
                ORDER BY timestamp DESC
            """)
            result = conn.execute(query)
            return result.fetchall()
            
    def mark_log_processed(self, log_id):
        """Mark a log as processed by AI"""
        with self.engine.connect() as conn:
            query = text("""
                UPDATE log_entries 
                SET pushed_to_ai = TRUE, 
                    pushed_at = :pushed_at 
                WHERE id = :log_id
            """)
            conn.execute(
                query,
                {"log_id": log_id, "pushed_at": datetime.utcnow()}
            )
            conn.commit()
            
    def add_anomaly(self, log_entry_id, device_id, anomaly_type, 
                    severity, confidence, description, metadata=None):
        """Add a new anomaly record"""
        with self.engine.connect() as conn:
            query = text("""
                INSERT INTO anomaly_records (
                    log_entry_id, device_id, timestamp, anomaly_type,
                    severity, confidence, description, metadata
                ) VALUES (
                    :log_entry_id, :device_id, :timestamp, :anomaly_type,
                    :severity, :confidence, :description, :metadata
                ) RETURNING id
            """)
            result = conn.execute(
                query,
                {
                    "log_entry_id": log_entry_id,
                    "device_id": device_id,
                    "timestamp": datetime.utcnow(),
                    "anomaly_type": anomaly_type,
                    "severity": severity,
                    "confidence": confidence,
                    "description": description,
                    "metadata": json.dumps(metadata) if metadata else None
                }
            )
            return result.fetchone()[0]
```

## Monitoring and Maintenance

### Key Metrics to Monitor
1. Log processing rate
2. Anomaly detection rate
3. Database query performance
4. Connection pool usage
5. Error rates

### Regular Maintenance Tasks
1. Clean up old anomaly records
2. Update anomaly patterns
3. Optimize database indexes
4. Monitor disk usage
5. Backup critical data

## Troubleshooting

### Common Issues
1. Database connection failures
2. Slow query performance
3. Duplicate anomaly records
4. Missing log entries
5. Incorrect anomaly classifications

### Debugging Steps
1. Check database connectivity
2. Verify query performance
3. Review error logs
4. Check system resources
5. Validate anomaly patterns

## Future Enhancements

### Planned Features
1. Real-time anomaly detection
2. Advanced pattern matching
3. Machine learning integration
4. Automated response actions
5. Enhanced reporting capabilities

### Potential Improvements
1. Distributed processing
2. Advanced caching
3. Enhanced security features
4. Improved monitoring
5. Better integration capabilities 