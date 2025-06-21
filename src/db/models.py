from sqlalchemy import Column, Integer, String, DateTime, Boolean, Text, JSON, ForeignKey, create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, relationship
from datetime import datetime
import os
import sys
import re
import json

# Add the src directory to the path for imports
sys.path.append(os.path.join(os.path.dirname(__file__), '..'))
from config import SQLALCHEMY_DATABASE_URL

Base = declarative_base()

class Device(Base):
    """Device table to store information about devices that send logs."""
    __tablename__ = 'devices'

    id = Column(Integer, primary_key=True, autoincrement=True)
    name = Column(String(128), nullable=False)
    ip_address = Column(String(45), nullable=False, unique=True)
    description = Column(Text)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Relationship to log entries
    log_entries = relationship("LogEntry", back_populates="device")

    def __repr__(self):
        return f"<Device(id={self.id}, name='{self.name}', ip='{self.ip_address}')>"

class LogEntry(Base):
    """Log entries table to store syslog messages - compatible with existing system."""
    __tablename__ = 'log_entries'

    id = Column(Integer, primary_key=True, autoincrement=True)
    device_id = Column(Integer, ForeignKey('devices.id'), nullable=False)
    device_ip = Column(String(45), nullable=False)
    timestamp = Column(DateTime, nullable=False)
    log_level = Column(String(50))
    process_name = Column(String(128))
    message = Column(Text, nullable=False)
    raw_message = Column(Text)
    structured_data = Column(JSON)
    pushed_to_ai = Column(Boolean, default=False)
    pushed_at = Column(DateTime)
    push_attempts = Column(Integer, default=0)
    last_push_error = Column(Text)

    # Relationship to device
    device = relationship("Device", back_populates="log_entries")

    def __repr__(self):
        return f"<LogEntry(id={self.id}, device_id={self.device_id}, timestamp={self.timestamp}, log_level='{self.log_level}')>"

def create_tables_if_not_exist():
    """Create database tables only if they don't exist."""
    try:
        engine = create_engine(SQLALCHEMY_DATABASE_URL)
        
        # Check if tables exist
        inspector = engine.dialect.inspector(engine)
        existing_tables = inspector.get_table_names()
        
        if 'log_entries' not in existing_tables or 'devices' not in existing_tables:
            print("Creating database tables...")
            Base.metadata.create_all(engine)
            print("Database tables created successfully.")
        else:
            print("Database tables already exist. Using existing schema.")
            
    except Exception as e:
        print(f"Error creating tables: {e}")
        raise

def create_tables():
    """Create all database tables (for new installations)."""
    engine = create_engine(SQLALCHEMY_DATABASE_URL)
    Base.metadata.create_all(engine)
    print("Database tables created successfully.")

def drop_tables():
    """Drop all database tables."""
    engine = create_engine(SQLALCHEMY_DATABASE_URL)
    Base.metadata.drop_all(engine)
    print("Database tables dropped successfully.")

def save_log_entry(parsed_message):
    """
    Save a parsed log message to the database.
    Compatible with existing system schema.
    
    Args:
        parsed_message (dict): Dictionary containing log message data
    """
    engine = None
    session = None
    
    try:
        # Create database engine and session
        engine = create_engine(SQLALCHEMY_DATABASE_URL)
        Session = sessionmaker(bind=engine)
        session = Session()
        
        # Get or create device record
        hostname = parsed_message.get('hostname', 'unknown')
        
        # Check if device exists
        device = session.query(Device).filter_by(ip_address=hostname).first()
        if not device:
            # Create new device
            device = Device(
                name=f"Device-{hostname}",
                ip_address=hostname,
                description=f"Auto-created device for {hostname}"
            )
            session.add(device)
            session.flush()  # Flush to get the ID without committing
        
        # Create new log entry
        log_entry = LogEntry(
            device_id=device.id,
            device_ip=hostname,
            timestamp=parsed_message.get('timestamp', datetime.utcnow()),
            log_level=parsed_message.get('severity', 'info'),
            process_name=parsed_message.get('program'),
            message=parsed_message.get('message', ''),
            raw_message=parsed_message.get('raw_message', ''),
            structured_data=json.dumps(parsed_message.get('structured_data', {})) if parsed_message.get('structured_data') else None,
            pushed_to_ai=False,
            push_attempts=0
        )
        
        # Add log entry to session
        session.add(log_entry)
        
        # Commit everything
        session.commit()
        
        print(f"Saved log entry: {log_entry}")
        
    except Exception as e:
        print(f"Error saving log entry: {e}")
        if session:
            session.rollback()
    finally:
        if session:
            session.close()
        if engine:
            engine.dispose()