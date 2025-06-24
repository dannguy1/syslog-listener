#!/bin/bash

# Database Status Check Script
# This script helps diagnose database connectivity and schema issues

echo "Database Status Check"
echo "===================="

# Load environment variables
ENV_FILE=""
if [ -f ".env" ]; then
    ENV_FILE=".env"
elif [ -f "example.env" ]; then
    ENV_FILE="example.env"
else
    echo "Error: No .env or example.env file found."
    exit 1
fi

echo "Loading configuration from $ENV_FILE..."

# Source the environment file
if [ -f "$ENV_FILE" ]; then
    while IFS= read -r line; do
        if [[ ! "$line" =~ ^[[:space:]]*# ]] && [[ -n "$line" ]]; then
            export "$line"
        fi
    done < "$ENV_FILE"
fi

# Set defaults
DB_NAME="${DB_NAME:-netmonitor_db}"
DB_USER="${DB_USER:-netmonitor_user}"
DB_PASSWORD="${DB_PASSWORD:-netmonitor_password}"
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"

echo "Configuration:"
echo "  Host: $DB_HOST"
echo "  Port: $DB_PORT"
echo "  Database: $DB_NAME"
echo "  User: $DB_USER"
echo ""

# Check PostgreSQL service status
echo "1. PostgreSQL Service Status:"
if command -v pg_lsclusters >/dev/null 2>&1; then
    echo "Available clusters:"
    sudo pg_lsclusters
    echo ""
    RUNNING_CLUSTERS=$(sudo pg_lsclusters | grep online | wc -l)
    if [ "$RUNNING_CLUSTERS" -gt 0 ]; then
        echo "✓ PostgreSQL clusters are running"
    else
        echo "✗ No PostgreSQL clusters are running"
    fi
else
    echo "pg_lsclusters not available, checking systemctl..."
    if sudo systemctl is-active --quiet postgresql; then
        echo "✓ PostgreSQL service is running"
    else
        echo "✗ PostgreSQL service is not running"
    fi
fi
echo ""

# Test basic connectivity
echo "2. Database Connectivity Test:"
if PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1;" > /dev/null 2>&1; then
    echo "✓ Database connection successful"
else
    echo "✗ Database connection failed"
    echo "  Testing connection details:"
    PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1;" 2>&1
fi
echo ""

# Check if tables exist
echo "3. Database Schema Check:"
TABLES=$(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' ORDER BY table_name;" 2>/dev/null | tr -d ' ')

if [ -n "$TABLES" ]; then
    echo "✓ Found tables in database:"
    echo "$TABLES" | while read -r table; do
        if [ -n "$table" ]; then
            echo "  - $table"
        fi
    done
else
    echo "✗ No tables found in database"
fi
echo ""

# Check specific required tables
echo "4. Required Tables Check:"
REQUIRED_TABLES=("devices" "log_entries")

for table in "${REQUIRED_TABLES[@]}"; do
    if PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = '$table');" 2>/dev/null | grep -q "t"; then
        echo "✓ $table table exists"
        
        # Check table access
        if PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "SELECT COUNT(*) FROM $table;" > /dev/null 2>&1; then
            echo "  ✓ $table table is accessible"
        else
            echo "  ✗ $table table access failed"
        fi
    else
        echo "✗ $table table does not exist"
    fi
done
echo ""

# Check user privileges
echo "5. User Privileges Check:"
if PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "SELECT current_user, current_database();" > /dev/null 2>&1; then
    echo "✓ User can connect and access database"
    
    # Check if user can create tables
    if PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "CREATE TABLE IF NOT EXISTS test_table_check (id int); DROP TABLE test_table_check;" > /dev/null 2>&1; then
        echo "✓ User has CREATE TABLE privileges"
    else
        echo "✗ User lacks CREATE TABLE privileges"
    fi
else
    echo "✗ User cannot access database"
fi
echo ""

# Check indexes
echo "6. Index Check:"
REQUIRED_INDEXES=(
    "ix_log_entries_device_id"
    "ix_log_entries_device_ip"
    "ix_log_entries_log_level"
    "ix_log_entries_process_name"
    "ix_log_entries_pushed_to_ai"
    "ix_log_entries_timestamp"
)

for index in "${REQUIRED_INDEXES[@]}"; do
    if PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT EXISTS (SELECT FROM pg_indexes WHERE indexname = '$index');" 2>/dev/null | grep -q "t"; then
        echo "✓ $index exists"
    else
        echo "✗ $index missing"
    fi
done
echo ""

echo "Status Check Complete"
echo "===================="
echo ""
echo "If you see any issues above, try running:"
echo "  ./scripts/setup_db.sh"
echo ""
echo "To test the Python application, run:"
echo "  python3 scripts/test_compatibility.py" 