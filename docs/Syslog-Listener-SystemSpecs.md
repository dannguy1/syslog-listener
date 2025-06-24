# Syslog Listener System Specification

## Table of Contents
1. [System Overview](#system-overview)
2. [Architecture](#architecture)
3. [Components](#components)
4. [Database Schema](#database-schema)
5. [Configuration](#configuration)
6. [Syslog Message Processing](#syslog-message-processing)
7. [Installation and Setup](#installation-and-setup)
8. [Usage](#usage)
9. [API Reference](#api-reference)
10. [Troubleshooting](#troubleshooting)

## System Overview

The Syslog Listener is a Python-based UDP service that receives, parses, and stores syslog messages from network devices. It provides a robust foundation for log collection and analysis, supporting both RFC 3164 and RFC 5424 syslog formats.

### Key Features
- **UDP Syslog Reception**: Listens on configurable host/port for syslog messages
- **Multi-Format Support**: Handles RFC 3164, RFC 5424, and common vendor variants
- **Robust Parsing**: Sophisticated regex-based parser with fallback mechanisms
- **PostgreSQL Storage**: Stores parsed logs with structured data
- **Device Management**: Automatic device discovery and tracking
- **AI Integration Ready**: Compatible with external AI analysis systems

### System Requirements
- **Python**: 3.8+
- **Database**: PostgreSQL 12+
- **OS**: Linux (tested on Raspberry Pi OS, Ubuntu)
- **Memory**: 512MB RAM minimum
- **Storage**: 1GB+ for logs (depending on retention)

## Architecture

```
┌─────────────────┐    UDP    ┌──────────────────┐    SQL    ┌─────────────────┐
│ Network Devices │ ────────► │ Syslog Listener  │ ────────► │ PostgreSQL DB   │
│ (Routers, etc.) │           │ (Python Service) │           │ (Log Storage)   │
└─────────────────┘           └──────────────────┘           └─────────────────┘
                                       │
                                       ▼
                              ┌──────────────────┐
                              │ Log Processing   │
                              │ (Parser, Device  │
                              │  Management)     │
                              └──────────────────┘
```

### Component Flow
1. **Network devices** send syslog messages via UDP
2. **SyslogServer** receives and decodes messages
3. **Parser** extracts structured data from raw messages
4. **Database Models** store logs and manage devices
5. **PostgreSQL** provides persistent storage

## Components

### 1. Main Application (`src/main.py`)
Entry point that initializes the system:
- Loads configuration from environment variables
- Sets up logging
- Creates database tables if needed
- Starts the syslog server

### 2. Configuration (`src/config.py`)
Manages application settings:
- Database connection parameters
- Syslog server host/port
- Logging configuration
- Environment variable loading

### 3. Syslog Server (`src/syslog_server.py`)
UDP server implementation:
- **Class**: `SyslogServer`
- **Protocol**: UDP socket binding
- **Message Handling**: Receives, decodes, and processes messages
- **Threading**: Single-threaded with blocking I/O

### 4. Message Parser (`src/utils/parser.py`)
Robust syslog message parsing:
- **RFC 3164 Support**: Traditional syslog format
- **RFC 5424 Support**: Modern syslog format
- **Fallback Parsing**: Handles malformed messages
- **Timestamp Parsing**: Flexible date/time handling
- **Process Extraction**: Identifies program names and PIDs

### 5. Database Models (`src/db/models.py`)
SQLAlchemy ORM definitions:
- **Device Model**: Network device information
- **LogEntry Model**: Syslog message storage
- **Relationships**: Device-to-log associations
- **CRUD Operations**: Save, query, and manage data

## Database Schema

### Devices Table
```sql
CREATE TABLE devices (
    id SERIAL PRIMARY KEY,
    name VARCHAR(128) NOT NULL,
    ip_address VARCHAR(45) NOT NULL UNIQUE,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

**Fields:**
- `id`: Auto-incrementing primary key
- `name`: Human-readable device name
- `ip_address`: Device IP address (unique)
- `description`: Optional device description
- `created_at`: Record creation timestamp
- `updated_at`: Last update timestamp

### Log Entries Table
```sql
CREATE TABLE log_entries (
    id SERIAL PRIMARY KEY,
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
```

**Fields:**
- `id`: Auto-incrementing primary key
- `device_id`: Foreign key to devices table
- `device_ip`: Denormalized IP for faster queries
- `timestamp`: Log message timestamp (UTC)
- `log_level`: Syslog severity level
- `process_name`: Program/process name
- `message`: Parsed log message content
- `raw_message`: Original unparsed message
- `structured_data`: JSON metadata (PID, priority, etc.)
- `pushed_to_ai`: AI processing status flag
- `pushed_at`: Last AI push timestamp
- `push_attempts`: Number of AI push attempts
- `last_push_error`: Last AI push error message

### Indexes
```sql
CREATE INDEX ix_log_entries_device_id ON log_entries(device_id);
CREATE INDEX ix_log_entries_device_ip ON log_entries(device_ip);
CREATE INDEX ix_log_entries_timestamp ON log_entries(timestamp);
CREATE INDEX ix_log_entries_log_level ON log_entries(log_level);
CREATE INDEX ix_log_entries_process_name ON log_entries(process_name);
CREATE INDEX ix_log_entries_pushed_to_ai ON log_entries(pushed_to_ai);
```

## Configuration

### Environment Variables
Configuration is managed via environment variables or `.env` file:

| Variable | Default | Description |
|----------|---------|-------------|
| `DB_NAME` | `netmonitor_db` | PostgreSQL database name |
| `DB_USER` | `netmonitor_user` | Database username |
| `DB_PASSWORD` | `netmonitor_password` | Database password |
| `DB_HOST` | `localhost` | Database host address |
| `DB_PORT` | `5432` | Database port |
| `SYSLOG_HOST` | `0.0.0.0` | Syslog listener host |
| `SYSLOG_PORT` | `514` | Syslog listener port |
| `LOG_LEVEL` | `ERROR` | Application log level |
| `LOG_FILE` | `syslog_listener.log` | Log file path |

### Configuration Class
```python
class Config:
    def __init__(self):
        self.db_user = DB_USER
        self.db_password = DB_PASSWORD
        self.db_host = DB_HOST
        self.db_port = DB_PORT
        self.db_name = DB_NAME
        self.database_url = SQLALCHEMY_DATABASE_URL
        self.host = SYSLOG_SERVER['HOST']
        self.port = SYSLOG_SERVER['PORT']
        self.log_level = LOGGING['LEVEL']
        self.log_file = LOGGING['FILE']
```

## Syslog Message Processing

### Supported Formats

#### RFC 3164 (Traditional)
```
<PRI>TIMESTAMP HOSTNAME PROGRAM[PID]: MESSAGE
```
**Example:**
```
<134>Dec 15 10:30:45 router sshd[1234]: Failed password for user admin
```

#### RFC 5424 (Modern)
```
<PRI>1 TIMESTAMP HOSTNAME APP PROCID MSGID [SD] MESSAGE
```
**Example:**
```
<134>1 2024-12-15T10:30:45.123Z router sshd 1234 ID001 [user@example.com] Failed login
```

#### No Priority Format
```
TIMESTAMP HOSTNAME PROGRAM[PID]: MESSAGE
```
**Example:**
```
Dec 15 10:30:45 router kernel: Interface eth0 up
```

### Parsing Process
1. **Priority Extraction**: Parse `<PRI>` and calculate severity/facility
2. **Timestamp Parsing**: Handle multiple formats with dateutil
3. **Hostname Extraction**: Identify source device
4. **Process Extraction**: Extract program name and PID
5. **Message Content**: Preserve original and parsed content
6. **Structured Data**: Store metadata in JSON format

### Severity Levels
| Code | Level | Description |
|------|-------|-------------|
| 0 | emergency | System is unusable |
| 1 | alert | Action must be taken immediately |
| 2 | critical | Critical conditions |
| 3 | error | Error conditions |
| 4 | warning | Warning conditions |
| 5 | notice | Normal but significant condition |
| 6 | info | Informational messages |
| 7 | debug | Debug-level messages |

## Installation and Setup

### Prerequisites
```bash
# Install PostgreSQL
sudo apt-get update
sudo apt-get install postgresql postgresql-contrib

# Install Python dependencies
pip install -r requirements.txt
```

### Database Setup
```bash
# Run database setup script
chmod +x scripts/setup_db.sh
./scripts/setup_db.sh
```

### Configuration
```bash
# Copy example configuration
cp example.env .env

# Edit configuration
nano .env
```

### Verification
```bash
# Test database compatibility
python3 scripts/test_compatibility.py

# Test message parsing
python3 test_parser.py
```

## Usage

### Starting the Service
```bash
# Direct execution
python3 src/main.py

# Using management script
./scripts/run_listener.sh start

# Background mode
./scripts/run_listener.sh start -b
```

### Management Commands
```bash
# Check status
./scripts/run_listener.sh status

# View logs
./scripts/run_listener.sh logs

# Stop service
./scripts/run_listener.sh stop

# Restart service
./scripts/run_listener.sh restart
```

### Testing
```bash
# Send test messages
python3 test_syslog_client.py

# Send real log data
./scripts/send_real_logs.sh -f syslog.txt -h localhost -p 514
```

## API Reference

### SyslogServer Class
```python
class SyslogServer:
    def __init__(self, host='0.0.0.0', port=514)
    def start()
    def stop()
```

### Parser Functions
```python
def parse_syslog_message(message: str) -> dict
def parse_flexible_timestamp(ts: str) -> datetime
def validate_syslog_message(message: str) -> bool
def format_for_storage(parsed_message: dict) -> dict
```

### Database Functions
```python
def save_log_entry(parsed_message: dict)
def create_tables_if_not_exist()
def create_tables()
def drop_tables()
```

### Device Management
```python
class Device(Base):
    # Auto-created for new IP addresses
    # Name format: "Device-{ip_address}"
    # Description: "Auto-created device for {ip_address}"
```

## Troubleshooting

### Common Issues

#### Database Connection Failed
```bash
# Check PostgreSQL status
sudo systemctl status postgresql

# Check database setup
./scripts/check_db_status.sh

# Verify credentials
PGPASSWORD=your_password psql -h localhost -U your_user -d your_db
```

#### Port Already in Use
```bash
# Check what's using the port
sudo lsof -i :514

# Kill existing process
sudo kill -9 <PID>

# Or use different port in .env
SYSLOG_PORT=10514
```

#### Permission Denied
```bash
# Run with sudo for privileged ports (<1024)
sudo python3 src/main.py

# Or use non-privileged port
SYSLOG_PORT=10514
```

#### Message Parsing Issues
```bash
# Test parser with specific message
python3 test_parser.py

# Check raw message storage
# Raw messages are always preserved in raw_message field
```

### Log Files
- **Application Logs**: `syslog_listener.log`
- **System Logs**: `/var/log/syslog`
- **Database Logs**: PostgreSQL logs

### Performance Considerations
- **UDP Buffer**: 1024 bytes per message
- **Database Connections**: Connection pooling via SQLAlchemy
- **Indexing**: Comprehensive indexes on query fields
- **Batch Processing**: Consider implementing for high-volume scenarios

### Security Considerations
- **Network Access**: Configure firewall rules
- **Database Security**: Use strong passwords and SSL
- **Privileged Ports**: Use non-privileged ports when possible
- **Log Sanitization**: Raw messages may contain sensitive data

---

**Version**: 1.0  
**Last Updated**: December 2024  
**Compatibility**: PostgreSQL 12+, Python 3.8+ 