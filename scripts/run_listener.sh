#!/bin/bash

# Syslog Listener Management Script
# This script sets up the environment and calls the Python management script

set -e

# Get the project root directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Function to setup environment
setup_environment() {
    echo "Setting up environment..."
    
    # Check if virtual environment exists
    if [ -d "$PROJECT_ROOT/venv" ]; then
        echo "Using virtual environment: $PROJECT_ROOT/venv"
        export VIRTUAL_ENV="$PROJECT_ROOT/venv"
        export PATH="$VIRTUAL_ENV/bin:$PATH"
        
        # Activate virtual environment
        source "$VIRTUAL_ENV/bin/activate"
        
        # Verify psycopg2 is installed
        if ! python -c "import psycopg2" 2>/dev/null; then
            echo "Installing missing dependencies..."
            pip install -r "$PROJECT_ROOT/requirements.txt"
        fi
    else
        echo "No virtual environment found. Using system Python."
        echo "Make sure required packages are installed:"
        echo "  pip install -r requirements.txt"
    fi
    
    # Set PYTHONPATH
    export PYTHONPATH="$PROJECT_ROOT/src:$PYTHONPATH"
    
    # Load environment variables
    if [ -f "$PROJECT_ROOT/.env" ]; then
        echo "Loading environment from .env file..."
        export $(grep -v '^#' "$PROJECT_ROOT/.env" | xargs)
    elif [ -f "$PROJECT_ROOT/src/example.env" ]; then
        echo "Loading environment from example.env file..."
        export $(grep -v '^#' "$PROJECT_ROOT/src/example.env" | xargs)
    fi
}

# Function to run with sudo if needed
run_with_sudo_if_needed() {
    local cmd="$1"
    local needs_sudo=false
    
    # Check if we need sudo for port 514
    if [[ "$cmd" == *"start"* ]]; then
        # Check if SYSLOG_PORT is set to 514 in environment
        if [[ "$SYSLOG_PORT" == "514" ]]; then
            needs_sudo=true
            echo "Note: Running on port 514 requires root privileges. Using sudo..."
        else
            echo "Using non-privileged port (default: 10514). No sudo required."
        fi
    fi
    
    if [ "$needs_sudo" = true ]; then
        # Preserve environment variables for sudo
        sudo -E python3 "$PROJECT_ROOT/scripts/run_listener.py" "$@"
    else
        python3 "$PROJECT_ROOT/scripts/run_listener.py" "$@"
    fi
}

# Main execution
main() {
    # Change to project root
    cd "$PROJECT_ROOT"
    
    # Setup environment
    setup_environment
    
    # Run the Python script with arguments
    run_with_sudo_if_needed "$@"
}

# Handle different commands
case "${1:-}" in
    start|stop|restart|status|logs)
        main "$@"
        ;;
    *)
        if [ $# -eq 0 ]; then
            echo "Usage: $0 {start|stop|restart|status|logs} [-b|--background]"
            echo ""
            echo "Commands:"
            echo "  start     - Start the syslog listener"
            echo "  stop      - Stop the syslog listener"
            echo "  restart   - Restart the syslog listener"
            echo "  status    - Show listener status"
            echo "  logs      - Show recent logs"
            echo ""
            echo "Options:"
            echo "  -b, --background - Run in background mode"
            echo ""
            echo "Examples:"
            echo "  $0 start          # Start in foreground"
            echo "  $0 start -b       # Start in background"
            echo "  $0 status         # Check status"
            echo "  $0 logs 100       # Show last 100 log lines"
            exit 0
        else
            echo "Unknown command: $1"
            echo "Use: start, stop, restart, status, or logs"
            exit 1
        fi
        ;;
esac 