#!/bin/bash

# Script to manage syslog listener logs

LOGS_DIR="logs"
LOG_FILE="$LOGS_DIR/syslog_listener.log"

echo "=== Syslog Listener Log Management ==="
echo

# Check if logs directory exists
if [ ! -d "$LOGS_DIR" ]; then
    echo "Logs directory does not exist. No logs to manage."
    exit 0
fi

# Show current log file sizes
echo "Current log file sizes:"
if [ -f "$LOG_FILE" ]; then
    echo "Main log file: $(du -h "$LOG_FILE" | cut -f1)"
else
    echo "Main log file: Not found"
fi

# Show rotated log files
echo
echo "Rotated log files:"
for file in "$LOGS_DIR"/syslog_listener.log.*; do
    if [ -f "$file" ]; then
        echo "$(basename "$file"): $(du -h "$file" | cut -f1)"
    fi
done

# Show last 10 lines of current log
echo
echo "Last 10 lines of current log:"
if [ -f "$LOG_FILE" ]; then
    tail -10 "$LOG_FILE"
else
    echo "No log file found"
fi

# Show total disk usage
echo
echo "Total disk usage for logs:"
du -sh "$LOGS_DIR" 2>/dev/null || echo "Cannot determine disk usage"

# Function to clean old logs
clean_logs() {
    echo
    echo "Cleaning old log files..."
    
    # Remove rotated log files older than 7 days
    find "$LOGS_DIR" -name "syslog_listener.log.*" -mtime +7 -delete 2>/dev/null
    
    # Truncate current log if it's larger than 10MB
    if [ -f "$LOG_FILE" ] && [ $(stat -c%s "$LOG_FILE") -gt 10485760 ]; then
        echo "Truncating large log file..."
        tail -1000 "$LOG_FILE" > "$LOG_FILE.tmp" && mv "$LOG_FILE.tmp" "$LOG_FILE"
    fi
    
    echo "Log cleanup completed"
}

# Check if cleanup was requested
if [ "$1" = "--clean" ]; then
    clean_logs
fi

echo
echo "Usage:"
echo "  $0          - Show log status"
echo "  $0 --clean  - Clean old log files" 