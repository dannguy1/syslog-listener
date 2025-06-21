#!/usr/bin/env python3
"""
Simple syslog client to test the syslog listener
"""

import socket
import time
import sys

def send_syslog_message(message, host='localhost', port=10514):
    """Send a syslog message to the specified host and port."""
    try:
        # Create UDP socket
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        
        # Format syslog message (RFC3164 format)
        timestamp = time.strftime("%b %d %H:%M:%S")
        syslog_message = f"<134>{timestamp} test-host test-app: {message}"
        
        # Send message
        sock.sendto(syslog_message.encode('utf-8'), (host, port))
        print(f"Sent: {syslog_message}")
        
        sock.close()
        return True
    except Exception as e:
        print(f"Error sending message: {e}")
        return False

def main():
    # Get port from command line or use default
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 10514
    host = sys.argv[2] if len(sys.argv) > 2 else 'localhost'
    
    print(f"Testing syslog listener on {host}:{port}")
    print("Press Ctrl+C to stop")
    
    try:
        while True:
            # Send a test message
            message = f"Test message at {time.strftime('%Y-%m-%d %H:%M:%S')}"
            send_syslog_message(message, host, port)
            time.sleep(5)  # Send message every 5 seconds
    except KeyboardInterrupt:
        print("\nStopping test client...")

if __name__ == "__main__":
    main() 