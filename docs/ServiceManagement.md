# Syslog Listener Service Management

This document describes how to manage the syslog listener service using the robust, port-based process management approach.

## Starting the Listener

To start the syslog listener in the background:

```bash
./scripts/run_listener.sh start -b
```

- The script will use `sudo` if required (e.g., for port 514).
- All environment variables are loaded from `.env` or `example.env`.
- Output is logged to `syslog_listener.out` in the project root.

## Stopping the Listener

To stop the syslog listener:

```bash
./scripts/run_listener.sh stop
```

- The script finds and stops any process bound to the syslog port (default: 514).
- Both graceful and forceful termination are attempted.

## Checking Status

To check if the listener is running:

```bash
./scripts/run_listener.sh status
```

- The script checks for any process bound to the syslog port.

## Viewing Logs

To view recent logs:

```bash
./scripts/run_listener.sh logs 100
```

- Shows the last 100 lines of the syslog listener log file.

## Environment Configuration

- Environment variables are loaded from `.env` (or `example.env` as fallback).
- Make sure your `.env` file contains all required settings (DB connection, SYSLOG_PORT, etc).

## Troubleshooting

- **Permission Denied on Port 514:**
  - The script uses `sudo` for privileged ports. You may be prompted for your password.
  - Make sure no other service (like `rsyslogd`) is using the port.
- **Listener Not Stopping:**
  - The script attempts both SIGTERM and SIGKILL. If the process persists, check for zombie processes or system-level restrictions.
- **Environment Not Loaded:**
  - Ensure your `.env` file is present and correctly formatted.
- **Logs Not Updating:**
  - Check that the listener process is running and writing to the correct log file.

## Deprecation Notice

- The Python management script (`run_listener.py`) is now deprecated and only calls the shell script for backward compatibility. 