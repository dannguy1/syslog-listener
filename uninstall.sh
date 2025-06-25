#!/bin/bash
set -e

# Configuration
SERVICE_NAME="syslog-listener"
SERVICE_USER="syslog"
DEV_DIR="$(cd "$(dirname "$0")" && pwd)"  # Development directory
INSTALL_DIR="/opt/syslog-listener"         # Installation directory

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Syslog Listener Uninstallation ===${NC}"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Error: This script must be run as root${NC}"
   echo "Please run: sudo $0"
   exit 1
fi

# Confirmation
echo -e "${YELLOW}This will remove the syslog-listener service and all its components.${NC}"
read -p "Are you sure you want to continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}Uninstallation cancelled.${NC}"
    exit 0
fi

echo ""

# 1. Stop and disable service
echo -e "${YELLOW}1. Stopping and disabling service...${NC}"
if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
    systemctl stop "$SERVICE_NAME"
    echo "Service stopped"
else
    echo "Service was not running"
fi

if systemctl is-enabled --quiet "$SERVICE_NAME" 2>/dev/null; then
    systemctl disable "$SERVICE_NAME"
    echo "Service disabled"
else
    echo "Service was not enabled"
fi

# 2. Remove systemd service file
echo -e "${YELLOW}2. Removing systemd service file...${NC}"
if [ -f "/etc/systemd/system/$SERVICE_NAME.service" ]; then
    rm -f "/etc/systemd/system/$SERVICE_NAME.service"
    systemctl daemon-reload
    echo "Systemd service file removed"
else
    echo "Systemd service file not found"
fi

# 3. Remove management scripts
echo -e "${YELLOW}3. Removing management scripts...${NC}"
for cmd in start stop status restart update; do
    if [ -f "/usr/local/bin/syslog-listener-$cmd" ]; then
        rm -f "/usr/local/bin/syslog-listener-$cmd"
        echo "Removed: /usr/local/bin/syslog-listener-$cmd"
    fi
done

# 4. Remove installation directory
echo -e "${YELLOW}4. Removing installation directory...${NC}"
if [ -d "$INSTALL_DIR" ]; then
    rm -rf "$INSTALL_DIR"
    echo "Installation directory removed: $INSTALL_DIR"
else
    echo "Installation directory not found: $INSTALL_DIR"
fi

# 5. Remove log directory
echo -e "${YELLOW}5. Removing log directory...${NC}"
if [ -d "/var/log/syslog-listener" ]; then
    rm -rf /var/log/syslog-listener
    echo "Log directory removed: /var/log/syslog-listener"
else
    echo "Log directory not found"
fi

# 6. Optional: Remove service user
echo -e "${YELLOW}6. Checking service user...${NC}"
if id "$SERVICE_USER" &>/dev/null; then
    read -p "Remove service user '$SERVICE_USER'? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        userdel -r "$SERVICE_USER" 2>/dev/null || userdel "$SERVICE_USER"
        echo "Service user removed: $SERVICE_USER"
    else
        echo "Service user kept: $SERVICE_USER"
    fi
else
    echo "Service user not found: $SERVICE_USER"
fi

# 7. Optional: Remove database
echo -e "${YELLOW}7. Checking database...${NC}"
DB_NAME="netmonitor_db"
DB_USER="netmonitor_user"

if sudo -u postgres psql -lqt 2>/dev/null | cut -d \| -f 1 | grep -qw "$DB_NAME"; then
    read -p "Remove database '$DB_NAME' and user '$DB_USER'? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sudo -u postgres dropdb "$DB_NAME" 2>/dev/null || echo "Failed to drop database"
        sudo -u postgres dropuser "$DB_USER" 2>/dev/null || echo "Failed to drop user"
        echo "Database and user removed"
    else
        echo "Database and user kept"
    fi
else
    echo "Database not found: $DB_NAME"
fi

echo ""
echo -e "${GREEN}=== Uninstallation Complete ===${NC}"
echo ""
echo "The syslog-listener service has been removed from the system."
echo ""
echo "Development directory remains: $DEV_DIR"
echo "To reinstall, run: sudo $DEV_DIR/install.sh" 