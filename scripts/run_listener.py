#!/usr/bin/env python3
"""
Comprehensive syslog listener management script
"""

import sys
import os
import subprocess
import signal
import time
from pathlib import Path

# Get the project root directory
SCRIPT_DIR = Path(__file__).parent
PROJECT_ROOT = SCRIPT_DIR.parent
PID_FILE = PROJECT_ROOT / "syslog_listener.pid"
LOG_FILE = PROJECT_ROOT / "syslog_listener.out"

def get_python_executable():
    """Get the Python executable path."""
    # Try virtual environment first
    venv_python = PROJECT_ROOT / "venv" / "bin" / "python"
    if venv_python.exists():
        return str(venv_python)
    
    # Fall back to system Python
    return "python3"

def is_running():
    """Check if the listener is running."""
    try:
        # Use pgrep to check if the process is running
        result = subprocess.run(['pgrep', '-f', 'main.py'], capture_output=True, text=True)
        if result.returncode == 0:
            pids = result.stdout.strip().split('\n')
            if pids and pids[0]:
                # Update PID file with the actual PID
                PID_FILE.write_text(pids[0])
                return True
    except Exception:
        pass
    
    # Fallback to PID file check
    if not PID_FILE.exists():
        return False
    
    try:
        pid = int(PID_FILE.read_text().strip())
        # Try to send signal 0 to check if process exists
        os.kill(pid, 0)
        return True
    except (ValueError, FileNotFoundError, OSError):
        return False

def get_pid():
    """Get the PID of the running listener."""
    if PID_FILE.exists():
        try:
            return int(PID_FILE.read_text().strip())
        except (ValueError, FileNotFoundError):
            pass
    return None

def check_port_usage(port=10514):
    """Check if a port is in use."""
    try:
        result = subprocess.run(['netstat', '-tuln'], capture_output=True, text=True)
        return str(port) in result.stdout
    except Exception:
        return False

def start_listener(background=False):
    """Start the syslog listener."""
    if is_running():
        print("Syslog listener is already running. Stopping it first...")
        stop_listener()
    
    # Check if we need sudo for port 514
    needs_sudo = False
    port = int(os.getenv('SYSLOG_PORT', 10514))
    
    if port == 514:
        needs_sudo = True
        print("Note: Running on port 514 requires root privileges. Using sudo...")
    else:
        print(f"Using port {port} (non-privileged). No sudo required.")
    
    # Change to src directory
    src_dir = PROJECT_ROOT / "src"
    os.chdir(src_dir)
    
    # Add current directory to Python path
    sys.path.insert(0, str(src_dir))
    
    if background:
        print("Starting syslog listener in background...")
        
        # Prepare command
        cmd = [get_python_executable(), "main.py"]
        
        # Prepare environment
        env = os.environ.copy()
        
        if needs_sudo:
            # When using sudo, we need to preserve environment variables
            # Use nohup to detach the process properly
            cmd = "sudo -E nohup " + " ".join(cmd) + " > /dev/null 2>&1 &"
            print("Using sudo with nohup for background execution...")
        else:
            # Use nohup for non-sudo background execution
            cmd = "nohup " + " ".join(cmd) + " > /dev/null 2>&1 &"
        
        # Start process
        with open(LOG_FILE, 'w') as log_file:
            process = subprocess.Popen(
                cmd,
                stdout=log_file,
                stderr=subprocess.STDOUT,
                cwd=src_dir,
                env=env,
                shell=True
            )
        
        # Wait a moment and check if it started
        time.sleep(3)
        
        # Check if the process is running by looking for it in the process list
        try:
            result = subprocess.run(['pgrep', '-f', 'main.py'], capture_output=True, text=True)
            if result.returncode == 0:
                pids = result.stdout.strip().split('\n')
                if pids and pids[0]:
                    pid = pids[0]
                    PID_FILE.write_text(pid)
                    print(f"Syslog listener started with PID {pid}.")
                    return True
        except Exception as e:
            print(f"Error checking process: {e}")
        
        print("Failed to start syslog listener in background.")
        # Check the log file for errors
        if LOG_FILE.exists():
            with open(LOG_FILE, 'r') as f:
                log_content = f.read()
                if log_content.strip():
                    print("Error log:")
                    print(log_content)
        return False
    else:
        print("Starting syslog listener in foreground (Ctrl+C to stop)...")
        
        try:
            # Import and run the main function
            from main import main
            main()
        except KeyboardInterrupt:
            print("\nSyslog listener stopped by user.")
        except Exception as e:
            print(f"Error starting syslog listener: {e}")
            return False
    
    return True

def stop_listener():
    """Stop the syslog listener."""
    pid = get_pid()
    if pid:
        try:
            # Try to send SIGTERM
            os.kill(pid, signal.SIGTERM)
            time.sleep(1)
            
            # Check if still running and force kill
            try:
                os.kill(pid, 0)  # Check if process exists
                os.kill(pid, signal.SIGKILL)
                print("Force killed syslog listener.")
            except OSError:
                print("Syslog listener stopped.")
        except OSError as e:
            if e.errno == 3:  # No such process
                print("Process not found.")
            elif e.errno == 1:  # Operation not permitted
                print("Permission denied. Trying with sudo...")
                subprocess.run(["sudo", "kill", str(pid)])
            else:
                print(f"Error stopping process: {e}")
        
        # Clean up PID file
        if PID_FILE.exists():
            PID_FILE.unlink()
    else:
        print("Syslog listener is not running.")
        if PID_FILE.exists():
            PID_FILE.unlink()

def restart_listener(background=False):
    """Restart the syslog listener."""
    stop_listener()
    time.sleep(1)
    start_listener(background)

def status():
    """Show the status of the syslog listener."""
    if is_running():
        pid = get_pid()
        port = int(os.getenv('SYSLOG_PORT', 10514))
        print(f"Syslog listener is running with PID {pid}.")
        
        # Check port usage
        if check_port_usage(port):
            print(f"✓ Port {port} is in use")
        else:
            print(f"⚠ Port {port} is not in use (might be using different port)")
        
        # Show log file if it exists
        if LOG_FILE.exists():
            print(f"Log file: {LOG_FILE}")
    else:
        print("Syslog listener is not running.")

def show_logs(lines=50):
    """Show recent logs."""
    if LOG_FILE.exists():
        try:
            with open(LOG_FILE, 'r') as f:
                log_lines = f.readlines()
                if log_lines:
                    print(f"Recent logs (last {lines} lines):")
                    print("-" * 50)
                    for line in log_lines[-lines:]:
                        print(line.rstrip())
                else:
                    print("Log file is empty.")
        except Exception as e:
            print(f"Error reading log file: {e}")
    else:
        print("No log file found.")

def main():
    """Main function."""
    if len(sys.argv) < 2:
        print("Usage: python3 scripts/run_listener.py {start|stop|restart|status|logs} [-b|--background]")
        print("  start     - Start the syslog listener")
        print("  stop      - Stop the syslog listener")
        print("  restart   - Restart the syslog listener")
        print("  status    - Show listener status")
        print("  logs      - Show recent logs")
        print("  -b, --background - Run in background mode")
        return
    
    # Parse arguments
    command = sys.argv[1]
    background = "-b" in sys.argv or "--background" in sys.argv
    
    if command == "start":
        start_listener(background)
    elif command == "stop":
        stop_listener()
    elif command == "restart":
        restart_listener(background)
    elif command == "status":
        status()
    elif command == "logs":
        lines = 50
        if len(sys.argv) > 2 and sys.argv[2].isdigit():
            lines = int(sys.argv[2])
        show_logs(lines)
    else:
        print(f"Unknown command: {command}")
        print("Use: start, stop, restart, status, or logs")

if __name__ == "__main__":
    main() 