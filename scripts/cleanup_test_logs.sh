#!/bin/bash

# Script to clean up test logs from the database
# This removes log entries and devices created during testing

set -e

# Get the project root directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Function to show usage
show_usage() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --all-devices     Remove all devices and their logs"
    echo "  --test-devices    Remove only test devices (localhost, 127.0.0.1, etc.)"
    echo "  --recent-hours N  Remove logs from the last N hours"
    echo "  --dry-run         Show what would be deleted without deleting"
    echo "  --help            Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --dry-run                    # Show what would be deleted"
    echo "  $0 --test-devices               # Remove test devices only"
    echo "  $0 --recent-hours 24            # Remove logs from last 24 hours"
    echo "  $0 --all-devices                # Remove all devices and logs"
}

# Parse command line arguments
DRY_RUN=false
REMOVE_ALL_DEVICES=false
REMOVE_TEST_DEVICES=false
RECENT_HOURS=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --all-devices)
            REMOVE_ALL_DEVICES=true
            shift
            ;;
        --test-devices)
            REMOVE_TEST_DEVICES=true
            shift
            ;;
        --recent-hours)
            RECENT_HOURS="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --help)
            show_usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Check if at least one option is specified
if [[ "$REMOVE_ALL_DEVICES" == false && "$REMOVE_TEST_DEVICES" == false && -z "$RECENT_HOURS" ]]; then
    echo "Error: Please specify at least one cleanup option"
    show_usage
    exit 1
fi

# Load environment
if [ -f "$PROJECT_ROOT/.env" ]; then
    echo "✓ Loading configuration from .env"
    export $(grep -v '^#' "$PROJECT_ROOT/.env" | xargs)
elif [ -f "$PROJECT_ROOT/src/example.env" ]; then
    echo "✓ Loading configuration from example.env"
    export $(grep -v '^#' "$PROJECT_ROOT/src/example.env" | xargs)
fi

# Add src directory to path
export PYTHONPATH="$PROJECT_ROOT/src:$PYTHONPATH"

# Function to run database cleanup
cleanup_database() {
    local cleanup_type="$1"
    local dry_run_flag=""
    
    if [[ "$DRY_RUN" == true ]]; then
        dry_run_flag="--dry-run"
        echo "🔍 DRY RUN MODE - No changes will be made"
        echo ""
    fi
    
    echo "🧹 Database Cleanup: $cleanup_type"
    echo "========================"
    
    # Change to src directory and run cleanup
    cd "$PROJECT_ROOT/src"
    
    python3 -c "
import sys
import os
from datetime import datetime, timedelta
from sqlalchemy import create_engine, text
from config import SQLALCHEMY_DATABASE_URL

def cleanup_database():
    engine = create_engine(SQLALCHEMY_DATABASE_URL)
    
    with engine.begin() as conn:
        # Get current statistics
        result = conn.execute(text('SELECT COUNT(*) FROM devices'))
        device_count = result.fetchone()[0]
        
        result = conn.execute(text('SELECT COUNT(*) FROM log_entries'))
        log_count = result.fetchone()[0]
        
        print(f'Current database state:')
        print(f'  Devices: {device_count}')
        print(f'  Log entries: {log_count}')
        print()
        
        if '$DRY_RUN' == 'true':
            print('🔍 DRY RUN - Would perform the following operations:')
        else:
            print('🗑️  Performing cleanup operations:')
        
        deleted_logs = 0
        deleted_devices = 0
        
        # Remove based on criteria
        if '$REMOVE_ALL_DEVICES' == 'true':
            # Remove all devices and their logs
            if '$DRY_RUN' == 'true':
                print('  - Would delete ALL devices and their logs')
                result = conn.execute(text('SELECT COUNT(*) FROM log_entries'))
                deleted_logs = result.fetchone()[0]
                result = conn.execute(text('SELECT COUNT(*) FROM devices'))
                deleted_devices = result.fetchone()[0]
            else:
                result = conn.execute(text('DELETE FROM log_entries'))
                deleted_logs = result.rowcount
                result = conn.execute(text('DELETE FROM devices'))
                deleted_devices = result.rowcount
                print(f'  - Deleted {deleted_logs} log entries')
                print(f'  - Deleted {deleted_devices} devices')
        
        elif '$REMOVE_TEST_DEVICES' == 'true':
            # Remove test devices (localhost, 127.0.0.1, etc.)
            test_ips = ['localhost', '127.0.0.1', '::1', '0.0.0.0']
            for ip in test_ips:
                if '$DRY_RUN' == 'true':
                    result = conn.execute(text('SELECT COUNT(*) FROM log_entries WHERE device_ip = :ip'), {'ip': ip})
                    count = result.fetchone()[0]
                    if count > 0:
                        print(f'  - Would delete {count} log entries from {ip}')
                        deleted_logs += count
                    
                    result = conn.execute(text('SELECT COUNT(*) FROM devices WHERE ip_address = :ip'), {'ip': ip})
                    count = result.fetchone()[0]
                    if count > 0:
                        print(f'  - Would delete {count} devices with IP {ip}')
                        deleted_devices += count
                else:
                    result = conn.execute(text('DELETE FROM log_entries WHERE device_ip = :ip'), {'ip': ip})
                    count = result.rowcount
                    if count > 0:
                        print(f'  - Deleted {count} log entries from {ip}')
                        deleted_logs += count
                    
                    result = conn.execute(text('DELETE FROM devices WHERE ip_address = :ip'), {'ip': ip})
                    count = result.rowcount
                    if count > 0:
                        print(f'  - Deleted {count} devices with IP {ip}')
                        deleted_devices += count
        
        elif '$RECENT_HOURS':
            # Remove logs from recent hours
            hours = int('$RECENT_HOURS')
            cutoff_time = datetime.utcnow() - timedelta(hours=hours)
            
            if '$DRY_RUN' == 'true':
                result = conn.execute(text('SELECT COUNT(*) FROM log_entries WHERE timestamp > :cutoff'), {'cutoff': cutoff_time})
                deleted_logs = result.fetchone()[0]
                print(f'  - Would delete {deleted_logs} log entries from last {hours} hours')
            else:
                result = conn.execute(text('DELETE FROM log_entries WHERE timestamp > :cutoff'), {'cutoff': cutoff_time})
                deleted_logs = result.rowcount
                print(f'  - Deleted {deleted_logs} log entries from last {hours} hours')
        
        # Show final statistics
        if '$DRY_RUN' == 'false':
            result = conn.execute(text('SELECT COUNT(*) FROM devices'))
            remaining_devices = result.fetchone()[0]
            
            result = conn.execute(text('SELECT COUNT(*) FROM log_entries'))
            remaining_logs = result.fetchone()[0]
            
            print()
            print('📊 Final database state:')
            print(f'  Devices: {remaining_devices}')
            print(f'  Log entries: {remaining_logs}')
        
        print()
        print('✅ Cleanup completed successfully')

if __name__ == '__main__':
    cleanup_database()
"
}

# Main execution
echo "🧹 Syslog Test Data Cleanup"
echo "==========================="
echo ""

if [[ "$DRY_RUN" == true ]]; then
    echo "🔍 DRY RUN MODE - No changes will be made to the database"
    echo ""
fi

# Perform cleanup based on options
if [[ "$REMOVE_ALL_DEVICES" == true ]]; then
    cleanup_database "Remove all devices and logs"
elif [[ "$REMOVE_TEST_DEVICES" == true ]]; then
    cleanup_database "Remove test devices only"
elif [[ -n "$RECENT_HOURS" ]]; then
    cleanup_database "Remove logs from last $RECENT_HOURS hours"
fi

echo ""
if [[ "$DRY_RUN" == true ]]; then
    echo "💡 To actually perform the cleanup, run without --dry-run"
fi 