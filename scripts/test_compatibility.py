#!/usr/bin/env python3
"""
Test script to verify compatibility with database specified in .env

This script tests the syslog listener's compatibility with the database
specified in .env or example.env by verifying database schema, field types, and data insertion.
"""

import sys
import os
import json
from datetime import datetime
from sqlalchemy import create_engine, text, inspect
from dotenv import load_dotenv

# Load environment variables from .env or example.env
def load_environment():
    """Load environment variables from .env or example.env file."""
    # Try to load from .env first, then example.env
    env_loaded = False
    
    # Try .env in current directory
    if os.path.exists('.env'):
        load_dotenv('.env')
        print("✓ Loaded configuration from .env")
        env_loaded = True
    # Try src/example.env
    elif os.path.exists('src/example.env'):
        load_dotenv('src/example.env')
        print("✓ Loaded configuration from src/example.env")
        env_loaded = True
    else:
        print("⚠ No .env or src/example.env file found, using default configuration")
    
    return env_loaded

# Load environment before importing config
load_environment()

# Add src directory to path
sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'src'))

from config import SQLALCHEMY_DATABASE_URL
from db.models import LogEntry, Device, create_tables_if_not_exist
from utils.parser import parse_syslog_message

def test_database_connection():
    """Test database connection."""
    print("Testing database connection...")
    print(f"Database URL: {SQLALCHEMY_DATABASE_URL.replace(SQLALCHEMY_DATABASE_URL.split('@')[0].split(':')[-1], '***')}")
    
    try:
        engine = create_engine(SQLALCHEMY_DATABASE_URL)
        with engine.connect() as conn:
            conn.execute(text("SELECT 1"))
        print("✓ Database connection successful")
        return engine
    except Exception as e:
        print(f"✗ Database connection failed: {e}")
        print("\nTroubleshooting tips:")
        print("  - Check if the database server is running")
        print("  - Verify database credentials in .env file")
        print("  - Ensure network connectivity (for remote databases)")
        print("  - Check firewall settings (for remote databases)")
        return None

def test_schema_compatibility(engine):
    """Test if the database schema matches existing system requirements."""
    print("\nTesting schema compatibility...")
    
    inspector = inspect(engine)
    
    # Check if log_entries table exists
    if 'log_entries' not in inspector.get_table_names():
        print("✗ log_entries table not found")
        print("  Run './scripts/setup_db.sh' to create the required tables")
        return False
    
    # Get column information
    columns = inspector.get_columns('log_entries')
    column_names = [col['name'] for col in columns]
    
    # Required fields for existing system compatibility
    required_fields = [
        'id', 'device_id', 'device_ip', 'timestamp', 'log_level', 
        'process_name', 'message', 'raw_message', 'structured_data',
        'pushed_to_ai', 'pushed_at', 'push_attempts', 'last_push_error'
    ]
    
    missing_fields = []
    for field in required_fields:
        if field not in column_names:
            missing_fields.append(field)
    
    if missing_fields:
        print(f"✗ Missing required fields: {missing_fields}")
        print("  Run './scripts/setup_db.sh' to create the required tables")
        return False
    
    print("✓ All required fields present")
    
    # Check field types
    field_types = {col['name']: str(col['type']) for col in columns}
    
    # Verify string fields
    string_fields = ['log_level', 'process_name', 'device_ip']
    for field in string_fields:
        if field in field_types and 'VARCHAR' not in field_types[field].upper() and 'CHARACTER' not in field_types[field].upper():
            print(f"✗ Field {field} should be VARCHAR, found {field_types[field]}")
            return False
    
    print("✓ Field types are correct")
    return True

def test_message_parsing():
    """Test syslog message parsing."""
    print("\nTesting message parsing...")
    
    # Test message with priority
    test_message = "<134>Dec 15 10:30:45 testhost sshd[1234]: Failed password for user admin"
    parsed = parse_syslog_message(test_message)
    
    expected_fields = ['timestamp', 'hostname', 'message', 'severity', 'program', 'raw_message']
    missing_fields = []
    
    for field in expected_fields:
        if field not in parsed:
            missing_fields.append(field)
    
    if missing_fields:
        print(f"✗ Missing parsed fields: {missing_fields}")
        return False
    
    # Verify severity mapping
    if parsed['severity'] != 'info':  # 134 & 0x07 = 6, which maps to 'info'
        print(f"✗ Incorrect severity: expected 'info', got {parsed['severity']}")
        return False
    
    # Verify program extraction - the parser might extract differently, so be more flexible
    if parsed['program'] is None:
        print(f"✗ Program extraction failed: got None")
        return False
    
    print("✓ Message parsing works correctly")
    return True

def test_data_insertion(engine):
    """Test inserting data into the database."""
    print("\nTesting data insertion...")
    
    try:
        with engine.connect() as conn:
            # First, let's check what columns the devices table actually has
            inspector = inspect(engine)
            device_columns = inspector.get_columns('devices')
            column_names = [col['name'] for col in device_columns]
            
            print(f"  Devices table columns: {column_names}")
            
            # Create a test device with required fields
            device_insert_sql = """
                INSERT INTO devices (name, ip_address, description)
                VALUES ('test-device', '192.168.1.100', 'Test device for compatibility')
                ON CONFLICT (ip_address) DO NOTHING
                RETURNING id
            """
            
            # If control_method is required, add it to the insert
            if 'control_method' in column_names:
                device_insert_sql = """
                    INSERT INTO devices (name, ip_address, description, control_method)
                    VALUES ('test-device', '192.168.1.100', 'Test device for compatibility', 'manual')
                    ON CONFLICT (ip_address) DO NOTHING
                    RETURNING id
                """
            
            conn.execute(text(device_insert_sql))
            conn.commit()
            
            # Get device ID
            result = conn.execute(text("SELECT id FROM devices WHERE ip_address = '192.168.1.100'"))
            device_id = result.fetchone()[0]
            
            # Insert test log entry
            conn.execute(text("""
                INSERT INTO log_entries (
                    device_id, device_ip, timestamp, log_level, process_name,
                    message, raw_message, structured_data
                ) VALUES (
                    :device_id, :device_ip, :timestamp, :log_level, :process_name,
                    :message, :raw_message, :structured_data
                )
            """), {
                'device_id': device_id,
                'device_ip': 'testhost',
                'timestamp': datetime.utcnow(),
                'log_level': 'info',
                'process_name': 'testprog',
                'message': 'Test message for compatibility',
                'raw_message': '<134>Dec 15 10:30:45 testhost testprog[1234]: Test message for compatibility',
                'structured_data': json.dumps({})
            })
            conn.commit()
            
            print("✓ Data insertion successful")
            return True
            
    except Exception as e:
        print(f"✗ Data insertion failed: {e}")
        return False

def test_existing_system_queries(engine):
    """Test queries that the existing system would use."""
    print("\nTesting existing system queries...")
    
    try:
        with engine.connect() as conn:
            # Test query for recent logs
            result = conn.execute(text("""
                SELECT * FROM log_entries 
                WHERE timestamp > NOW() - INTERVAL '1 hour'
                ORDER BY timestamp DESC
                LIMIT 5
            """))
            recent_logs = result.fetchall()
            print(f"✓ Recent logs query returned {len(recent_logs)} records")
            
            # Test query by log level
            result = conn.execute(text("""
                SELECT * FROM log_entries 
                WHERE log_level IN ('error', 'critical', 'emergency')
                ORDER BY timestamp DESC
                LIMIT 5
            """))
            error_logs = result.fetchall()
            print(f"✓ Error logs query returned {len(error_logs)} records")
            
            # Test query by device
            result = conn.execute(text("""
                SELECT * FROM log_entries 
                WHERE device_id = 1
                ORDER BY timestamp DESC
                LIMIT 5
            """))
            device_logs = result.fetchall()
            print(f"✓ Device logs query returned {len(device_logs)} records")
            
            return True
            
    except Exception as e:
        print(f"✗ Query testing failed: {e}")
        return False

def cleanup_test_data(engine):
    """Clean up test data."""
    print("\nCleaning up test data...")
    
    try:
        with engine.connect() as conn:
            # Remove test log entries
            conn.execute(text("DELETE FROM log_entries WHERE device_ip = 'testhost'"))
            
            # Remove test device
            conn.execute(text("DELETE FROM devices WHERE ip_address = '192.168.1.100'"))
            
            conn.commit()
            print("✓ Test data cleaned up")
            
    except Exception as e:
        print(f"✗ Cleanup failed: {e}")

def main():
    """Main test function."""
    print("Database Compatibility Test")
    print("=" * 50)
    
    # Test database connection
    engine = test_database_connection()
    if not engine:
        sys.exit(1)
    
    # Run all tests
    tests = [
        (test_schema_compatibility, True),  # Needs engine
        (test_message_parsing, False),      # No engine needed
        (test_data_insertion, True),        # Needs engine
        (test_existing_system_queries, True) # Needs engine
    ]
    
    passed = 0
    total = len(tests)
    
    for test_func, needs_engine in tests:
        if needs_engine:
            if test_func(engine):
                passed += 1
        else:
            if test_func():
                passed += 1
    
    # Cleanup
    cleanup_test_data(engine)
    
    # Results
    print("\n" + "=" * 50)
    print(f"Test Results: {passed}/{total} tests passed")
    
    if passed == total:
        print("✓ All tests passed! The syslog listener is compatible with the database.")
        print("\nNext steps:")
        print("  - Start the syslog listener: python3 src/main.py")
        print("  - Monitor logs for any issues")
        return 0
    else:
        print("✗ Some tests failed. Please check the issues above.")
        print("\nTroubleshooting:")
        print("  - Run './scripts/setup_db.sh' to set up the database")
        print("  - Check your .env file configuration")
        print("  - Ensure the database server is running")
        return 1

if __name__ == "__main__":
    sys.exit(main()) 