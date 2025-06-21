#!/bin/bash

# Syslog Listener Management Script
# This script sets up the environment and calls the Python management script

set -e

# Function to log messages
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

# Function to stop existing process by port
stop_process_by_port() {
    local port=$1
    local pid=$(sudo lsof -ti:$port 2>/dev/null || true)
    if [ ! -z "$pid" ]; then
        log "Stopping existing process on port $port (PID: $pid)..."
        sudo kill -15 $pid 2>/dev/null || true
        sleep 2
        # Force kill if still running
        if sudo kill -0 $pid 2>/dev/null; then
            log "Process still running, force killing..."
            sudo kill -9 $pid 2>/dev/null || true
        fi
    fi
}

# Get the project root directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Function to setup environment
setup_environment() {
    log "Setting up environment..."
    
    # Check if virtual environment exists
    if [ -d "$PROJECT_ROOT/venv" ]; then
        log "Using virtual environment: $PROJECT_ROOT/venv"
        export VIRTUAL_ENV="$PROJECT_ROOT/venv"
        export PATH="$VIRTUAL_ENV/bin:$PATH"
        
        # Activate virtual environment
        source "$VIRTUAL_ENV/bin/activate"
        
        # Verify psycopg2 is installed
        if ! python -c "import psycopg2" 2>/dev/null; then
            log "Installing missing dependencies..."
            pip install -r "$PROJECT_ROOT/requirements.txt"
        fi
    else
        log "No virtual environment found. Using system Python."
        log "Make sure required packages are installed:"
        log "  pip install -r requirements.txt"
    fi
    
    # Set PYTHONPATH
    export PYTHONPATH="$PROJECT_ROOT/src:$PYTHONPATH"
    
    # Load environment variables
    if [ -f "$PROJECT_ROOT/.env" ]; then
        log "Loading environment from .env file..."
        set -a
        source "$PROJECT_ROOT/.env"
        set +a
    elif [ -f "$PROJECT_ROOT/example.env" ]; then
        log "Loading environment from example.env file..."
        set -a
        source "$PROJECT_ROOT/example.env"
        set +a
    fi
}

# Function to start listener with proper sudo handling
start_listener_with_sudo() {
    local background=$1
    local port=${SYSLOG_PORT:-10514}
    
    # Stop any existing process on the port
    stop_process_by_port $port
    
    if [ "$background" = true ]; then
        log "Starting syslog listener in background on port $port..."
        
        # Remove existing PID file
        rm -f "$PROJECT_ROOT/syslog_listener.pid"
        
        # Start with sudo and proper environment variable handling
        cd "$PROJECT_ROOT/src"
        sudo bash -c 'env $(cat ../.env | xargs) \
        PYTHONPATH="$PROJECT_ROOT/src" \
        "$PROJECT_ROOT/venv/bin/python" main.py >> "$PROJECT_ROOT/syslog_listener.out" 2>&1 & echo $! > "$PROJECT_ROOT/syslog_listener.pid"'
        # Fix PID file ownership for the invoking user
        sudo chown $(id -u):$(id -g) "$PROJECT_ROOT/syslog_listener.pid"
        log "Syslog listener started in background (PID: $(cat "$PROJECT_ROOT/syslog_listener.pid"))"
        log "Logs are being written to $PROJECT_ROOT/syslog_listener.out"
    else
        log "Starting syslog listener in foreground on port $port..."
        cd "$PROJECT_ROOT/src"
        exec sudo env $(cat ../.env | xargs) \
        PYTHONPATH="$PROJECT_ROOT/src" \
        "$PROJECT_ROOT/venv/bin/python" main.py
    fi
}

# Function to check status by port
check_status_by_port() {
    local port=${SYSLOG_PORT:-10514}
    local pid=$(sudo lsof -ti:$port 2>/dev/null || true)
    
    if [ ! -z "$pid" ]; then
        log "Syslog listener is running with PID $pid on port $port"
        return 0
    else
        log "Syslog listener is not running on port $port"
        return 1
    fi
}

# Main execution
main() {
    # Change to project root
    cd "$PROJECT_ROOT"
    
    # Setup environment
    setup_environment
    
    # Parse command and options
    local command="${1:-}"
    local background=false
    
    # Check for background flag
    if [[ "$*" == *"-b"* ]] || [[ "$*" == *"--background"* ]]; then
        background=true
    fi
    
    case "$command" in
        start)
            start_listener_with_sudo $background
            ;;
        stop)
            local port=${SYSLOG_PORT:-10514}
            log "Stopping syslog listener on port $port..."
            stop_process_by_port $port
            rm -f "$PROJECT_ROOT/syslog_listener.pid"
            log "Syslog listener stopped"
            ;;
        restart)
            local port=${SYSLOG_PORT:-10514}
            log "Restarting syslog listener on port $port..."
            stop_process_by_port $port
            sleep 2
            start_listener_with_sudo $background
            ;;
        status)
            check_status_by_port
            ;;
        logs)
            local lines=${2:-50}
            if [ -f "$PROJECT_ROOT/syslog_listener.out" ]; then
                log "Recent logs (last $lines lines):"
                echo "----------------------------------------"
                tail -n $lines "$PROJECT_ROOT/syslog_listener.out"
            else
                log "No log file found"
            fi
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
                echo "Unknown command: $command"
                echo "Use: start, stop, restart, status, or logs"
                exit 1
            fi
            ;;
    esac
}

# Run main function
main "$@" 