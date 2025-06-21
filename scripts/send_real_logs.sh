#!/bin/bash

# Script to send real syslog data from syslog.txt to the syslog listener
# This provides realistic testing with actual network device logs

set -e

# Get the project root directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Configuration
SYSLOG_FILE="$PROJECT_ROOT/syslog.txt"
DEFAULT_HOST="localhost"
DEFAULT_PORT="10514"
DELAY_BETWEEN_MESSAGES=0.1  # 100ms delay between messages

# Function to show usage
show_usage() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -h, --host HOST     Target host (default: localhost)"
    echo "  -p, --port PORT     Target port (default: 10514)"
    echo "  -d, --delay SECONDS Delay between messages (default: 0.1)"
    echo "  -f, --file FILE     Syslog file to send (default: syslog.txt)"
    echo "  -n, --dry-run       Show what would be sent without sending"
    echo "  -v, --verbose       Show each message being sent"
    echo "  --help              Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                           # Send all logs with default settings"
    echo "  $0 -p 514                    # Send to standard syslog port"
    echo "  $0 -d 0.5                    # Send with 500ms delay"
    echo "  $0 -v                        # Verbose mode"
    echo "  $0 -n                        # Dry run (show messages only)"
}

# Parse command line arguments
HOST="$DEFAULT_HOST"
PORT="$DEFAULT_PORT"
DELAY="$DELAY_BETWEEN_MESSAGES"
VERBOSE=false
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--host)
            HOST="$2"
            shift 2
            ;;
        -p|--port)
            PORT="$2"
            shift 2
            ;;
        -d|--delay)
            DELAY="$2"
            shift 2
            ;;
        -f|--file)
            SYSLOG_FILE="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -n|--dry-run)
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

# Check if syslog file exists
if [[ ! -f "$SYSLOG_FILE" ]]; then
    echo "Error: Syslog file not found: $SYSLOG_FILE"
    exit 1
fi

# Count total lines
TOTAL_LINES=$(wc -l < "$SYSLOG_FILE")
echo "📊 Syslog Data Sender"
echo "====================="
echo "File: $SYSLOG_FILE"
echo "Target: $HOST:$PORT"
echo "Total messages: $TOTAL_LINES"
echo "Delay: ${DELAY}s between messages"
echo ""

if [[ "$DRY_RUN" == true ]]; then
    echo "🔍 DRY RUN MODE - No messages will be sent"
    echo ""
fi

# Function to send a syslog message
send_syslog_message() {
    local message="$1"
    local line_number="$2"
    
    if [[ "$DRY_RUN" == true ]]; then
        if [[ "$VERBOSE" == true ]]; then
            echo "[$line_number] Would send: $message"
        else
            echo "[$line_number] $message"
        fi
        return 0
    fi
    
    if [[ "$VERBOSE" == true ]]; then
        echo "[$line_number] Sending: $message"
    fi
    
    # Send the message using netcat
    echo "$message" | nc -u -w 1 "$HOST" "$PORT" 2>/dev/null || {
        echo "Warning: Failed to send message [$line_number]"
        return 1
    }
}

# Main execution
echo "🚀 Starting to send syslog messages..."
echo "Press Ctrl+C to stop"
echo ""

line_number=0
sent_count=0
failed_count=0

while IFS= read -r line; do
    line_number=$((line_number + 1))
    
    # Skip empty lines
    if [[ -z "$line" ]]; then
        continue
    fi
    
    # Send the message
    if send_syslog_message "$line" "$line_number"; then
        sent_count=$((sent_count + 1))
    else
        failed_count=$((failed_count + 1))
    fi
    
    # Show progress every 50 lines
    if [[ $((line_number % 50)) -eq 0 ]]; then
        echo "Progress: $line_number/$TOTAL_LINES messages processed"
    fi
    
    # Add delay between messages (except for dry run)
    if [[ "$DRY_RUN" == false ]] && [[ "$DELAY" != "0" ]]; then
        sleep "$DELAY"
    fi
    
done < "$SYSLOG_FILE"

# Summary
echo ""
echo "✅ Transmission Complete"
echo "======================="
echo "Total lines processed: $line_number"
echo "Messages sent: $sent_count"
echo "Messages failed: $failed_count"

if [[ "$DRY_RUN" == true ]]; then
    echo ""
    echo "💡 To actually send the messages, run without --dry-run"
fi 