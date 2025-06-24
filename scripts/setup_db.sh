#!/bin/bash

# Load environment variables from .env or example.env
ENV_FILE=""
if [ -f ".env" ]; then
    ENV_FILE=".env"
elif [ -f "src/example.env" ]; then
    ENV_FILE="src/example.env"
else
    echo "Error: No .env or src/example.env file found."
    echo "Please create a .env file with your database configuration."
    exit 1
fi

echo "Loading database configuration from $ENV_FILE..."

# Source the environment file
if [ -f "$ENV_FILE" ]; then
    # Read and export environment variables
    while IFS= read -r line; do
        # Skip comments and empty lines
        if [[ ! "$line" =~ ^[[:space:]]*# ]] && [[ -n "$line" ]]; then
            # Export the variable
            export "$line"
        fi
    done < "$ENV_FILE"
else
    echo "Error: Could not read $ENV_FILE"
    exit 1
fi

# Set default values if not provided in .env
DB_NAME="${DB_NAME:-netmonitor_db}"
DB_USER="${DB_USER:-netmonitor_user}"
DB_PASSWORD="${DB_PASSWORD:-netmonitor_password}"
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"

echo "Setting up local PostgreSQL database..."
echo "Host: $DB_HOST"
echo "Database: $DB_NAME"
echo "User: $DB_USER"
echo "Port: $DB_PORT"
echo ""

# Check if PostgreSQL is installed and running
echo "Checking PostgreSQL installation..."

# Check if PostgreSQL service exists
if ! systemctl list-unit-files | grep -q postgresql; then
    echo "Error: PostgreSQL is not installed."
    echo "Please install PostgreSQL first:"
    echo "  sudo apt-get update"
    echo "  sudo apt-get install postgresql postgresql-contrib"
    exit 1
fi

# Check which PostgreSQL clusters are available and running
echo "Checking PostgreSQL clusters..."
if command -v pg_lsclusters >/dev/null 2>&1; then
    CLUSTERS=$(sudo pg_lsclusters | grep online | awk '{print $1 " " $2}')
    if [ -z "$CLUSTERS" ]; then
        echo "Error: No PostgreSQL clusters are running."
        echo "Available clusters:"
        sudo pg_lsclusters
        echo ""
        echo "To start a cluster, run:"
        echo "  sudo pg_ctlcluster <version> <cluster> start"
        exit 1
    else
        echo "✓ Found running PostgreSQL clusters:"
        echo "$CLUSTERS"
    fi
else
    # Fallback: try to start PostgreSQL service
    if ! sudo systemctl is-active --quiet postgresql; then
        echo "Starting PostgreSQL service..."
        sudo systemctl start postgresql
        if [ $? -ne 0 ]; then
            echo "Error: Failed to start PostgreSQL service."
            exit 1
        fi
    fi
    echo "✓ PostgreSQL is running"
fi

# Create user if not exists
echo ""
echo "Setting up database user '$DB_USER'..."
if sudo -u postgres psql -c "SELECT 1 FROM pg_roles WHERE rolname='$DB_USER';" | grep -q 1; then
    echo "✓ User '$DB_USER' already exists"
else
    echo "Creating user '$DB_USER'..."
    sudo -u postgres psql -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASSWORD';"
    if [ $? -eq 0 ]; then
        echo "✓ User '$DB_USER' created successfully"
    else
        echo "✗ Failed to create user '$DB_USER'"
        exit 1
    fi
fi

# Grant necessary privileges
echo "Granting privileges to '$DB_USER'..."
sudo -u postgres psql -c "ALTER USER $DB_USER CREATEDB;" 2>/dev/null || echo "User already has CREATEDB privilege"
sudo -u postgres psql -c "ALTER USER $DB_USER WITH LOGIN;" 2>/dev/null || echo "User already has LOGIN privilege"

# Create database if not exists
echo ""
echo "Setting up database '$DB_NAME'..."
if sudo -u postgres psql -lqt | cut -d \| -f 1 | grep -qw "$DB_NAME"; then
    echo "✓ Database '$DB_NAME' already exists"
else
    echo "Creating database '$DB_NAME'..."
    sudo -u postgres psql -c "CREATE DATABASE $DB_NAME OWNER $DB_USER;"
    if [ $? -eq 0 ]; then
        echo "✓ Database '$DB_NAME' created successfully"
    else
        echo "✗ Failed to create database '$DB_NAME'"
        exit 1
    fi
fi

# Grant privileges on database
echo "Granting privileges on database '$DB_NAME'..."
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;"
sudo -u postgres psql -c "GRANT ALL ON SCHEMA public TO $DB_USER;"

# Test connection to the database
echo ""
echo "Testing database connection..."
if PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1;" > /dev/null 2>&1; then
    echo "✓ Connection to database successful"
else
    echo "✗ Failed to connect to database"
    echo "Please check:"
    echo "  - Database credentials in $ENV_FILE"
    echo "  - PostgreSQL configuration"
    echo ""
    echo "Current configuration:"
    echo "  DB_HOST=$DB_HOST"
    echo "  DB_PORT=$DB_PORT"
    echo "  DB_NAME=$DB_NAME"
    echo "  DB_USER=$DB_USER"
    exit 1
fi

# Function to check if table exists (more reliable method)
check_table_exists() {
    local table_name=$1
    local result
    result=$(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = '$table_name');" 2>/dev/null | tr -d ' ')
    if [ "$result" = "t" ]; then
        return 0  # Table exists
    else
        return 1  # Table does not exist
    fi
}

# Check if required tables exist
echo ""
echo "Checking existing database schema..."

# Check if devices table exists
if check_table_exists "devices"; then
    echo "✓ Devices table exists"
    DEVICES_EXISTS=true
else
    echo "✗ Devices table does not exist"
    DEVICES_EXISTS=false
fi

# Check if log_entries table exists
if check_table_exists "log_entries"; then
    echo "✓ Log entries table exists"
    LOG_ENTRIES_EXISTS=true
else
    echo "✗ Log entries table does not exist"
    LOG_ENTRIES_EXISTS=false
fi

# Create tables if they don't exist
echo ""
echo "Setting up database tables..."

if [ "$DEVICES_EXISTS" = false ]; then
    echo "Creating devices table..."
    PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" << 'EOF'
CREATE TABLE devices (
    id SERIAL PRIMARY KEY,
    name VARCHAR(128) NOT NULL,
    ip_address VARCHAR(45) NOT NULL UNIQUE,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
EOF
    if [ $? -eq 0 ]; then
        echo "✓ Devices table created successfully"
        DEVICES_EXISTS=true
    else
        echo "✗ Failed to create devices table"
        echo "Error details:"
        PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "CREATE TABLE devices (id SERIAL PRIMARY KEY, name VARCHAR(128) NOT NULL, ip_address VARCHAR(45) NOT NULL UNIQUE, description TEXT, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP);" 2>&1
        exit 1
    fi
fi

if [ "$LOG_ENTRIES_EXISTS" = false ]; then
    echo "Creating log_entries table..."
    PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" << 'EOF'
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
EOF
    if [ $? -eq 0 ]; then
        echo "✓ Log entries table created successfully"
        LOG_ENTRIES_EXISTS=true
    else
        echo "✗ Failed to create log_entries table"
        echo "Error details:"
        PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "CREATE TABLE log_entries (id SERIAL PRIMARY KEY, device_id INTEGER NOT NULL, device_ip VARCHAR(45) NOT NULL, timestamp TIMESTAMP NOT NULL, log_level VARCHAR(50), process_name VARCHAR(128), message TEXT NOT NULL, raw_message TEXT, structured_data JSON, pushed_to_ai BOOLEAN DEFAULT FALSE, pushed_at TIMESTAMP, push_attempts INTEGER DEFAULT 0, last_push_error TEXT, FOREIGN KEY (device_id) REFERENCES devices(id));" 2>&1
        exit 1
    fi
fi

# Grant comprehensive privileges on tables
echo "Granting comprehensive privileges on tables..."
PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO $DB_USER;" 2>/dev/null
PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO $DB_USER;" 2>/dev/null
PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO $DB_USER;" 2>/dev/null
PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO $DB_USER;" 2>/dev/null

# Create indexes if they don't exist
echo ""
echo "Setting up database indexes..."

# Function to check if index exists
check_index_exists() {
    local index_name=$1
    local result
    result=$(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT EXISTS (SELECT FROM pg_indexes WHERE indexname = '$index_name');" 2>/dev/null | tr -d ' ')
    if [ "$result" = "t" ]; then
        return 0  # Index exists
    else
        return 1  # Index does not exist
    fi
}

# Check and create indexes for log_entries table
INDEXES=(
    "ix_log_entries_device_id"
    "ix_log_entries_device_ip"
    "ix_log_entries_log_level"
    "ix_log_entries_process_name"
    "ix_log_entries_pushed_to_ai"
    "ix_log_entries_timestamp"
)

for index in "${INDEXES[@]}"; do
    if check_index_exists "$index"; then
        echo "✓ Index $index exists"
    else
        echo "Creating index $index..."
        case $index in
            "ix_log_entries_device_id")
                PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "CREATE INDEX ix_log_entries_device_id ON log_entries(device_id);"
                ;;
            "ix_log_entries_device_ip")
                PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "CREATE INDEX ix_log_entries_device_ip ON log_entries(device_ip);"
                ;;
            "ix_log_entries_log_level")
                PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "CREATE INDEX ix_log_entries_log_level ON log_entries(log_level);"
                ;;
            "ix_log_entries_process_name")
                PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "CREATE INDEX ix_log_entries_process_name ON log_entries(process_name);"
                ;;
            "ix_log_entries_pushed_to_ai")
                PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "CREATE INDEX ix_log_entries_pushed_to_ai ON log_entries(pushed_to_ai);"
                ;;
            "ix_log_entries_timestamp")
                PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "CREATE INDEX ix_log_entries_timestamp ON log_entries(timestamp);"
                ;;
        esac
        if [ $? -eq 0 ]; then
            echo "✓ Index $index created successfully"
        else
            echo "✗ Failed to create index $index"
        fi
    fi
done

# Test final connection and schema
echo ""
echo "Final verification..."

# Test connection
if PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "SELECT version();" > /dev/null 2>&1; then
    echo "✓ Database connection verified"
else
    echo "✗ Database connection failed"
    exit 1
fi

# Verify tables actually exist and are accessible
echo "Verifying table existence and access..."

if check_table_exists "devices"; then
    echo "✓ Devices table exists"
    if PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "SELECT COUNT(*) FROM devices;" > /dev/null 2>&1; then
        echo "✓ Devices table access verified"
    else
        echo "✗ Devices table access failed"
        exit 1
    fi
else
    echo "✗ Devices table does not exist"
    exit 1
fi

if check_table_exists "log_entries"; then
    echo "✓ Log entries table exists"
    if PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "SELECT COUNT(*) FROM log_entries;" > /dev/null 2>&1; then
        echo "✓ Log entries table access verified"
    else
        echo "✗ Log entries table access failed"
        exit 1
    fi
else
    echo "✗ Log entries table does not exist"
    exit 1
fi

# Display final table list
echo ""
echo "Final database schema:"
PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "\dt+"

echo ""
echo "=========================================="
echo "Local database setup completed successfully!"
echo "=========================================="
echo "Configuration loaded from: $ENV_FILE"
echo "Database Name: $DB_NAME"
echo "Database User: $DB_USER"
echo "Database Host: $DB_HOST"
echo "Database Port: $DB_PORT"
echo ""
echo "The syslog listener can now connect to the local database."
echo "To test the connection, run:"
echo "python3 scripts/test_compatibility.py"
echo ""
echo "To start the syslog listener, run:"
echo "python3 src/main.py" 