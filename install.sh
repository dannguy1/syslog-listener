#!/bin/bash
set -e

# Configuration
APP_NAME="syslog-listener"
DEV_DIR="$(cd "$(dirname "$0")" && pwd)"  # Development directory
INSTALL_DIR="/opt/syslog-listener"         # Installation directory
SERVICE_NAME="syslog-listener"
SERVICE_USER="syslog"
SERVICE_GROUP="syslog"
PYTHON_VERSION="3.11"
WRAPPER_SCRIPT="$INSTALL_DIR/start_syslog_listener.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Syslog Listener Installation ===${NC}"
echo "Installing syslog listener as a system service..."
echo "Development directory: $DEV_DIR"
echo "Installation directory: $INSTALL_DIR"
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Error: This script must be run as root${NC}"
   echo "Please run: sudo $0"
   exit 1
fi

# Update system packages
echo -e "${YELLOW}1. Updating system packages...${NC}"
apt-get update

# Install required system packages
echo -e "${YELLOW}2. Installing required system packages...${NC}"
apt-get install -y python3 python3-venv python3-pip postgresql postgresql-contrib netcat-openbsd

# Create service user
echo -e "${YELLOW}3. Creating service user...${NC}"
if ! id "$SERVICE_USER" &>/dev/null; then
    useradd -r -s /usr/sbin/nologin -d "$INSTALL_DIR" "$SERVICE_USER"
    echo "Created user: $SERVICE_USER"
else
    echo "User $SERVICE_USER already exists"
fi

# Create installation directory
echo -e "${YELLOW}4. Creating installation directory...${NC}"
mkdir -p "$INSTALL_DIR"
chown "$SERVICE_USER:$SERVICE_GROUP" "$INSTALL_DIR"

# Copy application files to installation directory
echo -e "${YELLOW}5. Copying application files...${NC}"
# Copy source code
cp -r "$DEV_DIR/src" "$INSTALL_DIR/"
# Copy requirements
cp "$DEV_DIR/requirements.txt" "$INSTALL_DIR/"
# Copy configuration template
cp "$DEV_DIR/example.env" "$INSTALL_DIR/.env.template"

# Set ownership of installed files
chown -R "$SERVICE_USER:$SERVICE_GROUP" "$INSTALL_DIR"

# Set up virtual environment in installation directory
echo -e "${YELLOW}6. Setting up Python virtual environment...${NC}"
if [ ! -d "$INSTALL_DIR/venv" ]; then
    python3 -m venv "$INSTALL_DIR/venv"
    echo "Created virtual environment"
else
    echo "Virtual environment already exists"
fi

# Install Python dependencies
echo -e "${YELLOW}7. Installing Python dependencies...${NC}"
"$INSTALL_DIR/venv/bin/pip" install --upgrade pip
"$INSTALL_DIR/venv/bin/pip" install -r "$INSTALL_DIR/requirements.txt"

# Database setup check and installation
echo -e "${YELLOW}8. Checking database setup...${NC}"
DB_NAME="netmonitor_db"
DB_USER="netmonitor_user"

# Check if database exists
if sudo -u postgres psql -lqt | cut -d \| -f 1 | grep -qw "$DB_NAME"; then
    echo -e "${BLUE}Database '$DB_NAME' already exists, skipping database setup${NC}"
else
    echo -e "${YELLOW}Database not found, setting up database...${NC}"
    if [ -f "$DEV_DIR/scripts/setup_db.sh" ]; then
        # Copy setup script temporarily and run it
        cp "$DEV_DIR/scripts/setup_db.sh" /tmp/setup_db.sh
        chmod +x /tmp/setup_db.sh
        cd /tmp && ./setup_db.sh
        rm /tmp/setup_db.sh
        echo "Database setup completed"
    else
        echo -e "${RED}Database setup script not found at $DEV_DIR/scripts/setup_db.sh${NC}"
        echo -e "${YELLOW}Please ensure the database setup script exists or manually create the database${NC}"
    fi
fi

# Create configuration file if it doesn't exist
echo -e "${YELLOW}9. Setting up configuration...${NC}"
if [ ! -f "$INSTALL_DIR/.env" ]; then
    cat > "$INSTALL_DIR/.env" << EOF
DB_NAME=netmonitor_db
DB_USER=netmonitor_user
DB_PASSWORD=netmonitor_password
DB_HOST=localhost
DB_PORT=5432
SYSLOG_HOST=0.0.0.0
SYSLOG_PORT=514
LOG_LEVEL=INFO
LOG_FILE=/var/log/syslog-listener/syslog_listener.log
EOF
    chown "$SERVICE_USER:$SERVICE_GROUP" "$INSTALL_DIR/.env"
    echo "Created default configuration file: $INSTALL_DIR/.env"
else
    echo "Configuration file already exists: $INSTALL_DIR/.env"
fi

# Create log directory
echo -e "${YELLOW}10. Setting up log directory...${NC}"
mkdir -p /var/log/syslog-listener
chown "$SERVICE_USER:$SERVICE_GROUP" /var/log/syslog-listener
echo "Log directory created: /var/log/syslog-listener"

# Create wrapper script
echo -e "${YELLOW}11. Creating wrapper script...${NC}"
cat > "$WRAPPER_SCRIPT" << EOF
#!/bin/bash
cd "$INSTALL_DIR"
source venv/bin/activate
exec python -m src.main
EOF
chmod +x "$WRAPPER_SCRIPT"
chown "$SERVICE_USER:$SERVICE_GROUP" "$WRAPPER_SCRIPT"
echo "Wrapper script created: $WRAPPER_SCRIPT"

# Create systemd service file
echo -e "${YELLOW}12. Creating systemd service...${NC}"
cat > "/etc/systemd/system/$SERVICE_NAME.service" << EOF
[Unit]
Description=Syslog Listener Service
After=network.target postgresql.service
Wants=postgresql.service

[Service]
Type=simple
User=$SERVICE_USER
Group=$SERVICE_GROUP
WorkingDirectory=$INSTALL_DIR
ExecStart=$WRAPPER_SCRIPT
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

# Security settings
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$INSTALL_DIR /var/log/syslog-listener

# Capabilities for binding to privileged port 514
AmbientCapabilities=CAP_NET_BIND_SERVICE
CapabilityBoundingSet=CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target
EOF
echo "Created systemd service: /etc/systemd/system/$SERVICE_NAME.service"

# Create management scripts
echo -e "${YELLOW}13. Creating management scripts...${NC}"

# Start script
cat > "/usr/local/bin/syslog-listener-start" << EOF
#!/bin/bash
systemctl start $SERVICE_NAME
systemctl status $SERVICE_NAME
EOF

# Stop script
cat > "/usr/local/bin/syslog-listener-stop" << EOF
#!/bin/bash
systemctl stop $SERVICE_NAME
systemctl status $SERVICE_NAME
EOF

# Status script
cat > "/usr/local/bin/syslog-listener-status" << EOF
#!/bin/bash
systemctl status $SERVICE_NAME
echo ""
echo "Recent logs:"
journalctl -u $SERVICE_NAME -n 20 --no-pager
EOF

# Restart script
cat > "/usr/local/bin/syslog-listener-restart" << EOF
#!/bin/bash
systemctl restart $SERVICE_NAME
systemctl status $SERVICE_NAME
EOF

# Update script
cat > "/usr/local/bin/syslog-listener-update" << EOF
#!/bin/bash
echo "Updating syslog-listener from development directory..."
DEV_DIR="$DEV_DIR"
INSTALL_DIR="$INSTALL_DIR"
SERVICE_USER="$SERVICE_USER"
SERVICE_GROUP="$SERVICE_GROUP"

# Stop service
systemctl stop $SERVICE_NAME

# Copy updated files
cp -r "\$DEV_DIR/src" "\$INSTALL_DIR/"
cp "\$DEV_DIR/requirements.txt" "\$INSTALL_DIR/"

# Update dependencies
"\$INSTALL_DIR/venv/bin/pip" install -r "\$INSTALL_DIR/requirements.txt"

# Set ownership
chown -R "\$SERVICE_USER:\$SERVICE_GROUP" "\$INSTALL_DIR"

# Restart service
systemctl start $SERVICE_NAME
systemctl status $SERVICE_NAME

echo "Update completed!"
EOF

# Make scripts executable
chmod +x /usr/local/bin/syslog-listener-*

echo "Created management scripts:"
echo "  syslog-listener-start"
echo "  syslog-listener-stop"
echo "  syslog-listener-status"
echo "  syslog-listener-restart"
echo "  syslog-listener-update"

# Reload systemd and enable service
echo -e "${YELLOW}14. Enabling systemd service...${NC}"
systemctl daemon-reload
systemctl enable "$SERVICE_NAME"

# Start the service
echo -e "${YELLOW}15. Starting service...${NC}"
systemctl start "$SERVICE_NAME"

# Wait a moment and check status
sleep 3
if systemctl is-active --quiet "$SERVICE_NAME"; then
    echo -e "${GREEN}✓ Service started successfully${NC}"
else
    echo -e "${RED}✗ Service failed to start${NC}"
    echo "Check logs with: journalctl -u $SERVICE_NAME"
    exit 1
fi

echo ""
echo -e "${GREEN}=== Installation Complete ===${NC}"
echo ""
echo "Service Information:"
echo "  Service Name: $SERVICE_NAME"
echo "  Status: $(systemctl is-active $SERVICE_NAME)"
echo "  Enabled: $(systemctl is-enabled $SERVICE_NAME)"
echo "  Installation Directory: $INSTALL_DIR"
echo ""
echo "Management Commands:"
echo "  Start:   syslog-listener-start"
echo "  Stop:    syslog-listener-stop"
echo "  Status:  syslog-listener-status"
echo "  Restart: syslog-listener-restart"
echo "  Update:  syslog-listener-update"
echo ""
echo "System Commands:"
echo "  Start:   systemctl start $SERVICE_NAME"
echo "  Stop:    systemctl stop $SERVICE_NAME"
echo "  Status:  systemctl status $SERVICE_NAME"
echo "  Logs:    journalctl -u $SERVICE_NAME -f"
echo ""
echo "Configuration:"
echo "  Config File: $INSTALL_DIR/.env"
echo "  Log File: /var/log/syslog-listener/syslog_listener.log"
echo ""
echo "Development:"
echo "  Development Directory: $DEV_DIR (unchanged)"
echo "  To update from development: syslog-listener-update"
echo ""
echo "The service will automatically start on boot."
echo "Remote hosts can send syslogs to: $(hostname -I | awk '{print $1}'):514" 