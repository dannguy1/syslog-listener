#!/bin/bash

# Script to restart the syslog listener with proper logging configuration

echo "Stopping existing syslog listener..."
sudo pkill -f "python main.py"

# Wait a moment for the process to stop
sleep 2

# Clean up the old output file if it exists
if [ -f "syslog_listener.out" ]; then
    echo "Removing old output file..."
    sudo rm -f syslog_listener.out
fi

# Create logs directory if it doesn't exist
mkdir -p logs

echo "Starting syslog listener with proper logging..."
# Start the listener in the background with nohup to prevent output to .out file
sudo nohup venv/bin/python src/main.py > /dev/null 2>&1 &

echo "Syslog listener restarted successfully!"
echo "Logs will be written to logs/syslog_listener.log with rotation"
echo "To check the logs: tail -f logs/syslog_listener.log"
echo "To check if it's running: ps aux | grep 'python main.py'" 