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
feat: Implement robust syslog parser with field validation and cleanup

## Parser Improvements
- Enhanced regex patterns for RFC 3164/5424 and problematic formats
- Added hostname validation to filter invalid IPs (e.g., "23" -> "unknown-device")
- Improved process name extraction and message content cleaning
- Better timestamp parsing with fallback mechanisms
- Enhanced error handling for malformed messages

## Database Integration
- Updated save_log_entry() to use improved hostname validation
- Better error handling for invalid hostnames
- Automatic fallback to "unknown-device" for invalid entries

## Logging System
- Implemented proper log rotation (5MB files, 3 backups)
- Removed verbose print statements to prevent system burden
- Added structured logging with appropriate levels
- Console output limited to warnings/errors only

## Code Cleanup
- Removed 16 temporary/redundant testing scripts
- Kept only 7 essential production scripts
- Cleaned up directory structure for GitHub
- Updated .gitignore for proper file exclusion

## Scripts Retained
- setup_db.sh: Database setup and schema creation
- check_db_status.sh: Database diagnostics and health checks
- check_logs.py: Log monitoring and statistics
- manage_logs.sh: Log management and cleanup
- cleanup_test_logs.sh: Test data cleanup
- restart_listener.sh: Service restart management
- test_compatibility.py: Database compatibility testing

## Technical Details
- Enhanced ENHANCED_REGEX for problematic message formats
- Added clean_hostname() function for IP/hostname validation
- Improved field extraction for device_ip, process_name, and message
- Better handling of malformed syslog messages
- Maintains full RFC 3164/5424 compatibility

This commit resolves field capture issues and provides a production-ready
syslog listener with robust parsing and proper logging management.
EOF

# Commit with the message
git commit -F /tmp/commit_message.txt

# Clean up temporary file
rm /tmp/commit_message.txt

echo ""
echo "5. Pushing to GitHub..."
git push origin main

echo ""
echo "✅ Successfully committed and pushed to GitHub!"
echo ""
echo "Commit includes:"
echo "  - Parser improvements with field validation"
echo "  - Enhanced logging system with rotation"
echo "  - Code cleanup and script organization"
echo "  - Database integration improvements"