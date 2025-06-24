# main.py

import sys
import logging
import os
from logging.handlers import RotatingFileHandler
from config import Config
from syslog_server import SyslogServer
from db.models import create_tables_if_not_exist

def setup_logging():
    """Set up logging with rotation to prevent log file bloat"""
    # Create logs directory if it doesn't exist
    os.makedirs('logs', exist_ok=True)
    
    # Set up logging configuration
    log_level = os.getenv('LOG_LEVEL', 'INFO').upper()
    
    # Create formatter
    formatter = logging.Formatter(
        '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    )
    
    # Set up root logger
    root_logger = logging.getLogger()
    root_logger.setLevel(getattr(logging, log_level, logging.INFO))
    
    # Clear any existing handlers
    root_logger.handlers.clear()
    
    # Console handler (only for errors and warnings when running in background)
    console_handler = logging.StreamHandler()
    console_handler.setLevel(logging.WARNING)
    console_handler.setFormatter(formatter)
    root_logger.addHandler(console_handler)
    
    # File handler with rotation (max 5MB per file, keep 3 files)
    file_handler = RotatingFileHandler(
        'logs/syslog_listener.log',
        maxBytes=5*1024*1024,  # 5MB
        backupCount=3
    )
    file_handler.setLevel(getattr(logging, log_level, logging.INFO))
    file_handler.setFormatter(formatter)
    root_logger.addHandler(file_handler)
    
    return logging.getLogger(__name__)

def main():
    # Set up logging
    logger = setup_logging()
    
    logger.info("Starting syslog listener...")

    # Load configuration
    config = Config()

    # Ensure database tables exist (create if needed)
    try:
        create_tables_if_not_exist()
        logger.info("Database tables verified/created successfully")
    except Exception as e:
        logger.error(f"Failed to setup database: {e}")
        sys.exit(1)

    # Initialize and start the syslog server
    try:
        server = SyslogServer(host=config.host, port=config.port)
        logger.info(f"Syslog listener starting on {config.host}:{config.port}")
        server.start()
    except Exception as e:
        logger.error(f"Failed to start syslog listener: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()