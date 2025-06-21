# main.py

import sys
import logging
from config import Config
from syslog_server import SyslogServer
from db.models import create_tables_if_not_exist

def main():
    # Set up logging
    logging.basicConfig(level=logging.INFO)
    logger = logging.getLogger(__name__)

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
        server.start()
        logger.info(f"Syslog listener started on port {config.port}")
    except Exception as e:
        logger.error(f"Failed to start syslog listener: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()