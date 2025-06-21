import re
from datetime import datetime

def parse_syslog_message(message):
    """
    Parse a syslog message and extract all relevant fields for the database.
    Compatible with existing system schema.
    
    Args:
        message (str): Raw syslog message
        
    Returns:
        dict: Parsed message with all required fields
    """
    try:
        # Store the original message
        raw_message = message
        
        # Standard syslog format: <PRI>TIMESTAMP HOSTNAME PROGRAM[PID]: MESSAGE
        # PRI = facility * 8 + severity
        
        # Extract priority if present (format: <PRI>)
        priority_match = re.match(r'<(\d+)>', message)
        severity = 'info'  # Default severity
        
        if priority_match:
            priority = int(priority_match.group(1))
            # Extract severity from priority (last 3 bits)
            severity_code = priority & 0x07
            severity_map = {
                0: 'emergency',
                1: 'alert', 
                2: 'critical',
                3: 'error',
                4: 'warning',
                5: 'notice',
                6: 'info',
                7: 'debug'
            }
            severity = severity_map.get(severity_code, 'info')
            # Remove priority from message for further parsing
            message = message[priority_match.end():]
        
        # Split the remaining message
        parts = message.strip().split()
        
        if len(parts) < 3:
            # If we can't parse properly, return basic info
            return {
                "timestamp": datetime.utcnow(),
                "hostname": "unknown",
                "message": message,
                "severity": severity,
                "raw_message": raw_message,
                "program": None,
                "structured_data": {}
            }
        
        # Try to parse timestamp (first two parts)
        timestamp_str = f"{parts[0]} {parts[1]}"
        try:
            # Try to parse common timestamp formats
            timestamp = datetime.strptime(timestamp_str, "%b %d %H:%M:%S")
            # Add current year since syslog doesn't include it
            timestamp = timestamp.replace(year=datetime.now().year)
            hostname = parts[2]
            remaining_parts = parts[3:]
        except ValueError:
            # If timestamp parsing fails, try to find hostname in a different way
            # Look for patterns like "hostname program[pid]:" or "hostname:"
            timestamp = datetime.utcnow()
            
            # Try to find hostname by looking for common patterns
            if len(parts) >= 2:
                # Check if second part looks like a hostname (no special chars)
                potential_hostname = parts[1]
                if re.match(r'^[a-zA-Z0-9\-_\.]+$', potential_hostname):
                    hostname = potential_hostname
                    remaining_parts = parts[2:]
                else:
                    # If second part doesn't look like hostname, use first part
                    hostname = parts[0]
                    remaining_parts = parts[1:]
            else:
                hostname = "unknown"
                remaining_parts = parts
        
        # Extract program name and PID
        program = None
        if remaining_parts:
            # Look for pattern like "program[pid]:" or "program:"
            process_match = re.match(r'^([^:[\]]+)(?:\[(\d+)\])?:?(.*)$', remaining_parts[0])
            if process_match:
                program = process_match.group(1)
                pid = process_match.group(2)
                message_content = process_match.group(3).strip()
                if message_content:
                    # If there's content after the process, it's part of the message
                    remaining_parts = [message_content] + remaining_parts[1:]
                else:
                    # Otherwise, the rest of the parts are the message
                    remaining_parts = remaining_parts[1:]
            else:
                # If no process pattern, the first part might be the program name
                program = remaining_parts[0]
                remaining_parts = remaining_parts[1:]
        
        # Join remaining parts as the message
        log_content = " ".join(remaining_parts) if remaining_parts else message
        
        # Extract structured data if present (RFC 5424 format)
        structured_data = {}
        if '[SD-ID' in log_content:
            # Extract structured data
            sd_match = re.search(r'\[([^\]]+)\]', log_content)
            if sd_match:
                structured_data = {"sd_id": sd_match.group(1)}
        
        return {
            "timestamp": timestamp,
            "hostname": hostname,
            "message": log_content,
            "severity": severity,
            "raw_message": raw_message,
            "program": program,
            "structured_data": structured_data
        }
        
    except Exception as e:
        # Fallback parsing if anything goes wrong
        return {
            "timestamp": datetime.utcnow(),
            "hostname": "unknown",
            "message": message,
            "severity": "info",
            "raw_message": message,
            "program": None,
            "structured_data": {}
        }

def validate_syslog_message(message):
    # Basic validation to check if the message is not empty
    if not message:
        return False
    return True

def format_for_storage(parsed_message):
    # Format the parsed message into a dictionary suitable for database storage
    return {
        "timestamp": parsed_message["timestamp"],
        "hostname": parsed_message["hostname"],
        "message": parsed_message["message"],
        "severity": parsed_message.get("severity", "info"),
        "raw_message": parsed_message.get("raw_message", ""),
        "program": parsed_message.get("program"),
        "structured_data": parsed_message.get("structured_data", {})
    }