# Syslog Listener Installation Guide

This guide explains how to install the syslog listener as a system service that runs automatically on boot, and how to properly uninstall it.

## Prerequisites

- Ubuntu/Debian-based system (tested on Raspberry Pi OS)
- Root access (sudo privileges)
- Internet connection for package installation

## Quick Installation

1. **Clone or download the syslog-listener project**
   ```bash
   cd /path/to/syslog-listener
   ```

2. **Run the installation script**
   ```bash
   sudo ./install.sh
   ```

The installation script will:
- Install required system packages (Python, PostgreSQL, etc.)
- Create a dedicated service user with proper permissions
- Set up Python virtual environment
- Install Python dependencies
- Check if database exists and skip setup if already present
- Configure PostgreSQL for remote access (if database setup needed)
- Create systemd service with proper wrapper script
- Set up logging
- Create management scripts
- Start the service

## What Gets Installed

### System Service
- **Service Name**: `syslog-listener`
- **User**: `syslog` (dedicated service user with `/usr/sbin/nologin` shell)
- **Auto-start**: Enabled (starts on boot)
- **Port**: 514 (standard syslog port)
- **Wrapper Script**: `start_syslog_listener.sh` (ensures proper virtual environment activation)

### Database
- **Database**: `netmonitor_db`
- **User**: `netmonitor_user`
- **Remote Access**: Enabled
- **Port**: 5432
- **Note**: Installation checks if database exists and skips setup if already present

### Management Scripts
The installation creates convenient management scripts in `/usr/local/bin/`:
- `syslog-listener-start` - Start the service
- `syslog-listener-stop` - Stop the service
- `syslog-listener-status` - Show service status
- `syslog-listener-restart` - Restart the service

## Configuration

### Environment Configuration
The service uses a `.env` file for configuration:
```bash
DB_NAME=netmonitor_db
DB_USER=netmonitor_user
DB_PASSWORD=netmonitor_password
DB_HOST=localhost
DB_PORT=5432
SYSLOG_HOST=0.0.0.0
SYSLOG_PORT=514
LOG_LEVEL=INFO
LOG_FILE=/var/log/syslog-listener/syslog_listener.log
```

### Database Configuration
The database is automatically configured for remote access. Remote hosts can connect using:
```bash
psql -h <server-ip> -p 5432 -U netmonitor_user -d netmonitor_db
```

## Usage

### Service Management

**Using management scripts:**
```bash
# Start the service
syslog-listener-start

# Stop the service
syslog-listener-stop

# Check status
syslog-listener-status

# Restart the service
syslog-listener-restart
```

**Using systemctl:**
```bash
# Start the service
sudo systemctl start syslog-listener

# Stop the service
sudo systemctl stop syslog-listener

# Check status
sudo systemctl status syslog-listener

# View logs
sudo journalctl -u syslog-listener -f

# Enable/disable auto-start
sudo systemctl enable syslog-listener
sudo systemctl disable syslog-listener
```

### Sending Syslog Messages

**From local system:**
```bash
# Using logger
logger -n 192.168.10.149 -P 514 "Test message"

# Using netcat
echo "<134>Jun 21 08:45:00 testhost app[123]: Test message" | nc -u 192.168.10.149 514
```

**From remote systems:**
```bash
# Replace 192.168.10.149 with your server's IP address
logger -n 192.168.10.149 -P 514 "Remote test message"
```

### Database Access

**Local access:**
```bash
psql -h localhost -p 5432 -U netmonitor_user -d netmonitor_db
```

**Remote access:**
```bash
psql -h <server-ip> -p 5432 -U netmonitor_user -d netmonitor_db
```

## Monitoring

### Service Logs
```bash
# View real-time logs
sudo journalctl -u syslog-listener -f

# View recent logs
sudo journalctl -u syslog-listener -n 50

# View logs since boot
sudo journalctl -u syslog-listener -b
```

### Application Logs
```bash
# View application log file
tail -f /var/log/syslog-listener/syslog_listener.log
```

### Database Monitoring
```bash
# Connect to database and check recent entries
psql -h localhost -p 5432 -U netmonitor_user -d netmonitor_db -c "
SELECT id, device_ip, timestamp, log_level, message 
FROM log_entries 
ORDER BY id DESC 
LIMIT 10;
"
```

## Troubleshooting

### Service Won't Start
1. Check service status:
   ```bash
   sudo systemctl status syslog-listener
   ```

2. Check logs:
   ```bash
   sudo journalctl -u syslog-listener -n 50
   ```

3. Common issues and solutions:

   **Issue**: `Failed at step EXEC spawning /path/to/python: No such file or directory`
   **Solution**: The wrapper script ensures proper virtual environment activation. Check if the wrapper script exists and is executable.

   **Issue**: `ModuleNotFoundError: No module named 'config'`
   **Solution**: Ensure the `src/__init__.py` file exists and the imports in `main.py` use relative imports (e.g., `from .config import Config`).

   **Issue**: `Permission denied` errors
   **Solution**: The service user needs access to the application directory. The installer sets proper permissions.

   **Issue**: Port 514 already in use
   **Solution**: Check what's using the port: `sudo netstat -tulpn | grep :514`

### Database Connection Issues
1. Check PostgreSQL status:
   ```bash
   sudo systemctl status postgresql
   ```

2. Test database connection:
   ```bash
   psql -h localhost -p 5432 -U netmonitor_user -d netmonitor_db -c "SELECT 1;"
   ```

3. Check PostgreSQL configuration:
   ```bash
   sudo grep "listen_addresses" /etc/postgresql/15/main/postgresql.conf
   sudo tail -5 /etc/postgresql/15/main/pg_hba.conf
   ```

### Firewall Issues
If remote connections fail, ensure port 5432 is open:
```bash
# Check if firewall is blocking
sudo ufw status
sudo iptables -L | grep 5432
```

### Virtual Environment Issues
If the service can't find Python packages:
```bash
# Check if virtual environment is properly set up
sudo -u syslog /home/dannguyen/syslog-listener/start_syslog_listener.sh
```

## Uninstallation

To remove the syslog listener service:
```bash
sudo ./uninstall.sh
```

The uninstall script will:
- Stop and disable the service
- Remove systemd service file
- Remove management scripts
- Remove wrapper script
- Remove log directory
- Optionally remove service user and database (with confirmation)

### Manual Uninstallation Steps

If the uninstall script is not available, you can manually remove the service:

1. **Stop and disable the service:**
   ```bash
   sudo systemctl stop syslog-listener
   sudo systemctl disable syslog-listener
   ```

2. **Remove systemd service file:**
   ```bash
   sudo rm /etc/systemd/system/syslog-listener.service
   sudo systemctl daemon-reload
   ```

3. **Remove management scripts:**
   ```bash
   sudo rm /usr/local/bin/syslog-listener-*
   ```

4. **Remove wrapper script:**
   ```bash
   sudo rm /path/to/syslog-listener/start_syslog_listener.sh
   ```

5. **Remove log directory:**
   ```bash
   sudo rm -rf /var/log/syslog-listener
   ```

6. **Optionally remove service user:**
   ```bash
   sudo userdel -r syslog
   ```

7. **Optionally remove database:**
   ```bash
   sudo -u postgres dropdb netmonitor_db
   sudo -u postgres dropuser netmonitor_user
   ```

## Security Considerations

1. **Service User**: The service runs as a dedicated `syslog` user with `/usr/sbin/nologin` shell (allows script execution but prevents login)
2. **Port 514**: Requires root privileges to bind to privileged port (handled by systemd capabilities)
3. **Database**: Configured for remote access - consider firewall rules
4. **Logs**: Service logs are stored in system journal and application logs
5. **Configuration**: Sensitive data in `.env` file - ensure proper file permissions
6. **Directory Permissions**: The installer sets proper permissions for the service user to access the application directory

## Important Notes

### Database Installation Behavior
- The installer checks if the database `netmonitor_db` already exists
- If the database exists, the installer skips database setup
- If the database doesn't exist, the installer runs the database setup script
- This allows for safe reinstallation without losing existing data

### Service User Shell
- The service user uses `/usr/sbin/nologin` instead of `/bin/false`
- This allows the user to execute scripts while preventing interactive login
- This resolves the permission issues encountered with `/bin/false`

### Wrapper Script
- The installer creates a wrapper script that properly activates the virtual environment
- This ensures all Python dependencies are available when the service runs
- The wrapper script uses `python -m src.main` to run the application as a module

### Relative Imports
- The application uses relative imports (e.g., `from .config import Config`)
- This requires running the application as a module with `python -m src.main`
- The wrapper script handles this automatically

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review service logs: `sudo journalctl -u syslog-listener`
3. Check application logs: `/var/log/syslog-listener/syslog_listener.log`
4. Verify database connectivity and configuration
5. Test the wrapper script manually: `sudo -u syslog /path/to/syslog-listener/start_syslog_listener.sh`
