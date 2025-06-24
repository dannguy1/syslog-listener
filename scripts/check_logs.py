#!/usr/bin/env python3
"""
Script to check log record count and database statistics
"""

import sys
import os
from datetime import datetime, timedelta
from dotenv import load_dotenv
from sqlalchemy import create_engine, text

# Load environment variables from .env or example.env
def load_environment():
    """Load environment variables from .env or example.env file."""
    if os.path.exists('.env'):
        load_dotenv('.env')
        print("✓ Loaded configuration from .env")
    elif os.path.exists('src/example.env'):
        load_dotenv('src/example.env')
        print("✓ Loaded configuration from src/example.env")
    else:
        print("⚠ No .env or src/example.env file found, using default configuration")

# Load environment before importing config
load_environment()

# Add src directory to path
sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'src'))

from config import SQLALCHEMY_DATABASE_URL

def check_log_statistics():
    """Check log record count and provide statistics."""
    print("Log Record Statistics")
    print("=" * 50)
    
    try:
        engine = create_engine(SQLALCHEMY_DATABASE_URL)
        
        with engine.connect() as conn:
            # Total counts
            print("\n📊 Total Records:")
            result = conn.execute(text("SELECT COUNT(*) FROM devices"))
            device_count = result.fetchone()[0]
            print(f"  Devices: {device_count}")
            
            result = conn.execute(text("SELECT COUNT(*) FROM log_entries"))
            log_count = result.fetchone()[0]
            print(f"  Log Entries: {log_count}")
            
            # Recent activity (last 24 hours)
            print("\n🕒 Recent Activity (Last 24 hours):")
            yesterday = datetime.utcnow() - timedelta(days=1)
            result = conn.execute(text("""
                SELECT COUNT(*) FROM log_entries 
                WHERE timestamp > :yesterday
            """), {'yesterday': yesterday})
            recent_count = result.fetchone()[0]
            print(f"  Log Entries: {recent_count}")
            
            # Log levels breakdown
            print("\n📈 Log Levels Breakdown:")
            result = conn.execute(text("""
                SELECT log_level, COUNT(*) as count 
                FROM log_entries 
                GROUP BY log_level 
                ORDER BY count DESC
            """))
            levels = result.fetchall()
            for level, count in levels:
                print(f"  {level or 'unknown'}: {count}")
            
            # Top devices
            print("\n🏠 Top Devices (by log count):")
            result = conn.execute(text("""
                SELECT device_ip, COUNT(*) as count 
                FROM log_entries 
                GROUP BY device_ip 
                ORDER BY count DESC 
                LIMIT 10
            """))
            devices = result.fetchall()
            for device_ip, count in devices:
                print(f"  {device_ip}: {count} logs")
            
            # Recent entries
            print("\n📝 Recent Log Entries:")
            result = conn.execute(text("""
                SELECT device_ip, log_level, process_name, message, timestamp 
                FROM log_entries 
                ORDER BY timestamp DESC 
                LIMIT 5
            """))
            recent_logs = result.fetchall()
            for device_ip, log_level, process_name, message, timestamp in recent_logs:
                # Truncate long messages
                short_message = message[:60] + "..." if len(message) > 60 else message
                print(f"  [{timestamp}] {device_ip} ({log_level}) {process_name or 'unknown'}: {short_message}")
            
            # Database size info
            print("\n💾 Database Information:")
            result = conn.execute(text("""
                SELECT 
                    schemaname,
                    tablename,
                    attname,
                    n_distinct,
                    correlation
                FROM pg_stats 
                WHERE tablename IN ('devices', 'log_entries')
                ORDER BY tablename, attname
            """))
            stats = result.fetchall()
            if stats:
                print("  Table statistics available")
            else:
                print("  No statistics available yet")
            
            print("\n" + "=" * 50)
            print("✓ Statistics retrieved successfully")
            return True
            
    except Exception as e:
        print(f"✗ Error retrieving statistics: {e}")
        return False

def check_specific_device(device_ip):
    """Check logs for a specific device."""
    print(f"\n🔍 Logs for device: {device_ip}")
    print("-" * 30)
    
    try:
        engine = create_engine(SQLALCHEMY_DATABASE_URL)
        
        with engine.connect() as conn:
            # Count logs for this device
            result = conn.execute(text("""
                SELECT COUNT(*) FROM log_entries WHERE device_ip = :device_ip
            """), {'device_ip': device_ip})
            count = result.fetchone()[0]
            print(f"Total logs: {count}")
            
            if count > 0:
                # Recent logs for this device
                result = conn.execute(text("""
                    SELECT log_level, process_name, message, timestamp 
                    FROM log_entries 
                    WHERE device_ip = :device_ip 
                    ORDER BY timestamp DESC 
                    LIMIT 10
                """), {'device_ip': device_ip})
                logs = result.fetchall()
                
                print("\nRecent logs:")
                for log_level, process_name, message, timestamp in logs:
                    short_message = message[:80] + "..." if len(message) > 80 else message
                    print(f"  [{timestamp}] ({log_level}) {process_name or 'unknown'}: {short_message}")
            
            return True
            
    except Exception as e:
        print(f"✗ Error: {e}")
        return False

def main():
    """Main function."""
    if len(sys.argv) > 1:
        # Check specific device
        device_ip = sys.argv[1]
        check_specific_device(device_ip)
    else:
        # Show general statistics
        check_log_statistics()

if __name__ == "__main__":
    main() 