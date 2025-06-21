#!/usr/bin/env python3
"""
Simple syslog listener management script (legacy support)
This script is now mainly for backward compatibility.
The main functionality is handled by run_listener.sh
"""

import sys
import os
import subprocess
from pathlib import Path

# Get the project root directory
SCRIPT_DIR = Path(__file__).parent
PROJECT_ROOT = SCRIPT_DIR.parent

def main():
    """Main function - delegate to shell script."""
    print("Note: This Python script is deprecated.")
    print("Please use: ./scripts/run_listener.sh")
    print()
    
    # Call the shell script with the same arguments
    script_path = PROJECT_ROOT / "scripts" / "run_listener.sh"
    if script_path.exists():
        subprocess.run([str(script_path)] + sys.argv[1:])
    else:
        print("Error: run_listener.sh not found!")
        sys.exit(1)

if __name__ == "__main__":
    main() 