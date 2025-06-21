# Syslog Listener

[![Python](https://img.shields.io/badge/Python-3.8+-blue.svg)](https://www.python.org/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-12+-green.svg)](https://www.postgresql.org/)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A Python-based syslog listener that receives syslog messages and stores them in a PostgreSQL database. Designed for seamless integration with existing External AI Analyzer systems without requiring database migrations.

## 🚀 Features

- ✅ **UDP Syslog Reception**: Listens for syslog messages on configurable port
- ✅ **PostgreSQL Storage**: Stores messages in structured database tables
- ✅ **Message Parsing**: Extracts priority, facility, severity, hostname, program, and message content
- ✅ **Device Management**: Automatically creates device records for new hosts
- ✅ **JSON Support**: Handles structured data in JSON format
- ✅ **Environment Configuration**: Uses .env files for easy configuration
- ✅ **Compatibility Testing**: Built-in tests to verify system compatibility
- ✅ **Real Data Testing**: Tools for testing with actual syslog data
- ✅ **Cleanup Utilities**: Scripts to manage test data and database maintenance

## 📋 Table of Contents

- [Quick Start](#quick-start)
- [Installation](#installation)
- [Configuration](#configuration)
- [Usage](#usage)
- [Database Schema](#database-schema)
- [Testing](#testing)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [License](#license)

## ⚡ Quick Start

### Prerequisites

- Python 3.8 or higher
- PostgreSQL 12 or higher
- Virtual environment (recommended)

### 1. Clone and Setup

```bash
git clone <repository-url>
cd syslog-listener

# Create virtual environment
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt
```

### 2. Setup Database

```bash
# Setup local PostgreSQL database
bash scripts/setup_db.sh

# Or run compatibility test to verify setup
python3 scripts/test_compatibility.py
```

### 3. Configure Environment

Create a `.env` file in the project root:

```env
DB_NAME=netmonitor_db
DB_USER=netmonitor_user
DB_PASSWORD=netmonitor_password
DB_HOST=localhost
DB_PORT=5432
SYSLOG_HOST=0.0.0.0
SYSLOG_PORT=10514
LOG_LEVEL=INFO
```

### 4. Start the Listener

```bash
# Recommended: Use the shell wrapper (handles environment setup)
bash scripts/run_listener.sh start

# Start in background mode
bash scripts/run_listener.sh start -b

# Alternative: Direct Python execution
python3 scripts/run_listener.py start
```

### 5. Test the System

```bash
# Test with syslog client (sends messages every 5 seconds)
python3 test_syslog_client.py

# Send real syslog data from syslog.txt
bash scripts/send_real_logs.sh

# Check database statistics
python3 scripts/check_logs.py
```

## 🔧 Installation

### System Requirements

- **Python**: 3.8 or higher
- **PostgreSQL**: 12 or higher
- **Operating System**: Linux, macOS, or Windows
- **Memory**: Minimum 512MB RAM
- **Storage**: 1GB free space

### Dependencies

The system requires the following Python packages (see `requirements.txt`):

- `sqlalchemy` - Database ORM
- `psycopg2-binary` - PostgreSQL adapter
- `python-dotenv` - Environment variable management
- `flask` - Web framework (for future features)

### Installation Steps

1. **Clone the repository**:
   ```bash
   git clone <repository-url>
   cd syslog-listener
   ```

2. **Create virtual environment**:
   ```bash
   python3 -m venv venv
   source venv/bin/activate
   ```

3. **Install dependencies**:
   ```bash
   pip install -r requirements.txt
   ```

4. **Setup database**:
   ```bash
   bash scripts/setup_db.sh
   ```

## ⚙️ Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `DB_NAME` | `netmonitor_db` | PostgreSQL database name |
| `DB_USER` | `netmonitor_user` | Database username |
| `DB_PASSWORD` | `netmonitor_password` | Database password |
| `DB_HOST` | `localhost` | Database host address |
| `DB_PORT` | `5432` | Database port |
| `SYSLOG_HOST` | `0.0.0.0` | Syslog listener host |
| `SYSLOG_PORT` | `10514` | Syslog listener port |
| `LOG_LEVEL` | `INFO` | Application log level |

### Port Configuration

- **Default Port**: `10514` (non-privileged)
- **Standard Syslog Port**: `514` (requires root privileges)
- **Custom Port**: Set `SYSLOG_PORT` in your `.env` file

## 📖 Usage

### Available Scripts

#### Core Scripts
- **`scripts/run_listener.sh`**: **Recommended** - Shell wrapper with environment setup
  - Automatically activates virtual environment
  - Handles sudo requirements for port 514
  - Loads environment variables
  - Installs missing dependencies
- **`scripts/run_listener.py`**: Direct Python management script
- **`test_syslog_client.py`**: Simple syslog client for testing

#### Database Scripts
- **`scripts/setup_db.sh`**: Setup local PostgreSQL database
- **`scripts/test_compatibility.py`**: Verify database compatibility
- **`scripts/check_logs.py`**: Advanced log statistics and device analysis
- **`scripts/send_real_logs.sh`**: Send real syslog data from syslog.txt for testing
- **`scripts/cleanup_test_logs.sh`**: Clean up test data from the database

### Listener Management

#### Syslog Listener Service Management

### Starting the Listener

```bash
./scripts/run_listener.sh start -b
```
- Starts the syslog listener in the background.

### Stopping the Listener

```bash
./scripts/run_listener.sh stop
```
- Stops any process bound to the syslog port (default: 514).

### Checking Status

```bash
./scripts/run_listener.sh status
```
- Checks if the syslog listener is running on the configured port.

### Viewing Logs

```bash
./scripts/run_listener.sh logs 100
```
- Shows the last 100 lines of the syslog listener log.

### Environment Configuration

- The script loads environment variables from `.env` (or `example.env` as fallback).
- Ensure your `.env` file is up to date with all required settings.

### Notes
- The script uses `sudo` for privileged ports. You may be prompted for your password.
- The Python management script (`run_listener.py`) is now deprecated and only calls the shell script.

### Testing

```bash
# Test with syslog client (sends messages every 5 seconds)
python3 test_syslog_client.py

# Send real syslog data from syslog.txt
bash scripts/send_real_logs.sh

# Send real data with custom settings
bash scripts/send_real_logs.sh -p 514 -d 0.2 -v

# Dry run (show what would be sent)
bash scripts/send_real_logs.sh -n

# Check database statistics
python3 scripts/check_logs.py

# Check specific device
python3 scripts/check_logs.py 192.168.1.100

# Clean up test data
bash scripts/cleanup_test_logs.sh --dry-run
bash scripts/cleanup_test_logs.sh --test-devices
bash scripts/cleanup_test_logs.sh --recent-hours 24
```

### Send Test Messages

```bash
# Using the test client (sends messages every 5 seconds)
python3 test_syslog_client.py

# Using logger command
logger -n localhost -P 10514 "Test message"

# Using netcat
echo "<134>Dec 15 10:30:45 testhost sshd[1234]: Test message" | nc -u localhost 10514
```

## 🗄️ Database Schema

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

### External AI Analyzer Compatibility

This system is designed to work seamlessly with existing External AI Analyzer databases:

- ✅ **No Migration Required**: Works directly with existing databases
- ✅ **Schema Compatibility**: Uses the exact same table structure
- ✅ **Data Preservation**: All existing data remains untouched
- ✅ **AI Integration**: Supports `pushed_to_ai` tracking for external analysis

## 🧪 Testing

### Test Types

1. **Unit Tests**: Individual component testing
2. **Integration Tests**: Database and syslog integration
3. **Real Data Tests**: Testing with actual syslog data
4. **Compatibility Tests**: External AI Analyzer compatibility

### Running Tests

```bash
# Run all tests
python3 -m pytest

# Run with coverage
python3 -m pytest --cov=src

# Run specific test
python3 -m pytest tests/test_parser.py
```

### Test Data Management

```bash
# Send test data
bash scripts/send_real_logs.sh

# Clean up test data
bash scripts/cleanup_test_logs.sh --test-devices

# Verify cleanup
python3 scripts/check_logs.py
```

## 🔍 Troubleshooting

### Common Issues

#### Permission Denied Error
If you get `[Errno 13] Permission denied` when starting the listener:
- **Recommended**: Use the shell wrapper which handles sudo automatically: `bash scripts/run_listener.sh start`
- **Alternative**: Use `sudo` for port 514: `sudo python3 scripts/run_listener.py start`
- **Alternative**: Change to a non-privileged port in your `.env` file: `SYSLOG_PORT=10514`

#### Missing Dependencies
If you get `No module named 'psycopg2'` errors:
- **Recommended**: Use the shell wrapper which installs dependencies automatically: `bash scripts/run_listener.sh start`
- **Manual fix**: Install dependencies: `