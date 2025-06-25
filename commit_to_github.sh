#!/bin/bash

echo "Committing Syslog Listener Improvements to GitHub"
echo "================================================"

# Check if we're in a git repository
if [ ! -d ".git" ]; then
    echo "Error: Not in a git repository"
    exit 1
fi

# Check git status
echo "1. Checking git status..."
git status

echo ""
echo "2. Adding all changes..."
git add .

echo ""
echo "3. Checking what will be committed..."
git status --porcelain

echo ""
echo "4. Committing changes with comprehensive message..."

# Create comprehensive commit message
cat > /tmp/commit_message.txt << 'EOF'
feat: Fix import issues and improve install/uninstall scripts

## Import Fixes
- Fixed ModuleNotFoundError by converting absolute imports to relative imports
- Updated src/syslog_server.py: from .utils.parser import parse_syslog_message
- Updated src/db/models.py: from ..config import SQLALCHEMY_DATABASE_URL
- Updated src/main.py: from .config import Config, from .syslog_server import SyslogServer
- Added missing __init__.py files in src/utils/ and src/db/ directories
- Fixed wrapper script path quoting for better compatibility

## Install Script Improvements
- Fixed database setup script reference from setup_remote_db.sh to setup_db.sh
- Added /var/log/syslog-listener to ReadWritePaths in systemd service
- Improved wrapper script creation with proper dynamic paths
- Enhanced error handling and security settings

## Uninstall Script Improvements
- Added error suppression (2>/dev/null) to prevent errors on non-existent services
- Enhanced user removal logic to handle cases where user home directory is app directory
- Added error suppression for database checks
- Improved reinstallation instructions based on what was removed

## Systemd Service Enhancements
- Added proper log directory permissions
- Enhanced security settings with ReadWritePaths
- Improved service dependencies and restart behavior

## Git Configuration
- Fixed git ownership issues by adding safe.directory configuration
- Resolved permission problems preventing file updates

## Technical Details
- All imports now use relative syntax (., ..) for proper module resolution
- Wrapper script uses quoted paths for better shell compatibility
- Systemd service includes proper log directory access
- Uninstall script handles edge cases gracefully

This commit resolves the ModuleNotFoundError issues and provides
robust installation/uninstallation scripts for production deployment.
EOF

# Commit with the message
git commit -F /tmp/commit_message.txt

# Clean up temporary file
rm /tmp/commit_message.txt

echo ""
echo "5. Pushing to GitHub..."
git push origin dev

echo ""
echo "✅ Successfully committed and pushed to GitHub!"
echo ""
echo "Commit includes:"
echo "  - Import fixes for ModuleNotFoundError"
echo "  - Improved install/uninstall scripts"
echo "  - Enhanced systemd service configuration"
echo "  - Git ownership and permission fixes"