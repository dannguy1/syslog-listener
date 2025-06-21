# Configuration settings for the syslog listener application

import os
from dotenv import load_dotenv

# Load environment variables from .env file if present
dotenv_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), '.env')
load_dotenv(dotenv_path)

# Database configuration - compatible with External AI Analyzer
DB_USER = os.getenv("DB_USER", "netmonitor_user")
DB_PASSWORD = os.getenv("DB_PASSWORD", "netmonitor_password")
DB_HOST = os.getenv("DB_HOST", "192.168.10.14")
DB_PORT = os.getenv("DB_PORT", "5432")
DB_NAME = os.getenv("DB_NAME", "netmonitor_db")

# External AI Analyzer compatible database URL
SQLALCHEMY_DATABASE_URL = (
    f"postgresql+psycopg2://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_NAME}"
)

# Syslog server configuration
SYSLOG_SERVER = {
    'HOST': os.getenv('SYSLOG_HOST', '0.0.0.0'),  # Default to listen on all interfaces
    'PORT': int(os.getenv('SYSLOG_PORT', 10514)),  # Use non-privileged port by default
}

# Logging configuration
LOGGING = {
    'LEVEL': os.getenv('LOG_LEVEL', 'INFO'),       # Default logging level
    'FILE': os.getenv('LOG_FILE', 'syslog_listener.log'),  # Default log file
}

class Config:
    """Configuration class for the syslog listener application."""
    
    def __init__(self):
        self.db_user = DB_USER
        self.db_password = DB_PASSWORD
        self.db_host = DB_HOST
        self.db_port = DB_PORT
        self.db_name = DB_NAME
        self.database_url = SQLALCHEMY_DATABASE_URL
        
        self.host = SYSLOG_SERVER['HOST']
        self.port = SYSLOG_SERVER['PORT']
        
        self.log_level = LOGGING['LEVEL']
        self.log_file = LOGGING['FILE']
    
    @property
    def database_url(self):
        return self._database_url
    
    @database_url.setter
    def database_url(self, value):
        self._database_url = value