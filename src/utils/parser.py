import re
from datetime import datetime
from dateutil import parser as dateutil_parser

# RFC 3164: <PRI>MMM dd HH:MM:SS HOST PROC[PID]: MSG
RFC3164_REGEX = re.compile(
    r'^<(?P<pri>\d{1,3})>'
    r'(?P<timestamp>\w{3}\s+\d{1,2}\s+\d{2}:\d{2}:\d{2})\s+'
    r'(?P<hostname>[\w\.-]+)\s+'
    r'(?:(?P<process>[\w\/\.-]+)(?:\[(?P<pid>\d+)\])?:\s+)?'
    r'(?P<message>.*)$'
)

# RFC 5424: <PRI>1 YYYY-MM-DDTHH:MM:SS(.sss)?(Z|±hh:mm)? HOST APP PROCID MSGID [SD] MSG
RFC5424_REGEX = re.compile(
    r'^<(?P<pri>\d{1,3})>1\s+'
    r'(?P<timestamp>\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[-+]\d{2}:?\d{2})?)\s+'
    r'(?P<hostname>[\w\.-]+)\s+'
    r'(?P<appname>[\w\.-]+)\s+'
    r'(?P<procid>[\w\.-]+)\s+'
    r'(?P<msgid>[\w\.-]+)\s+'
    r'(?P<structured_data>(\[[^\]]*\])*)\s*'
    r'(?P<message>.*)$'
)

# No priority, fallback for common syslog lines
NO_PRI_REGEX = re.compile(
    r'^(?P<timestamp>\w{3}\s+\d{1,2}\s+\d{2}:\d{2}:\d{2})\s+'
    r'(?P<hostname>[\w\.-]+)\s+'
    r'(?:(?P<process>[\w\/\.-]+)(?:\[(?P<pid>\d+)\])?:\s+)?'
    r'(?P<message>.*)$'
)

# Enhanced regex for problematic formats (like the ones we saw in logs)
ENHANCED_REGEX = re.compile(
    r'^(?:<(?P<pri>\d{1,3})>)?'
    r'(?:(?P<timestamp>\d{1,2}:\s+\d{2}:\d{2})\s+)?'
    r'(?P<hostname>[\w\.-]+)\s+'
    r'(?:(?P<process>[\w\/\.-]+)(?:\[(?P<pid>\d+)\])?:\s+)?'
    r'(?P<message>.*)$'
)

# Fallback: just try to get a message
FALLBACK_REGEX = re.compile(r'^(?P<message>.*)$')

SEVERITY_MAP = {
    0: 'emergency', 1: 'alert', 2: 'critical', 3: 'error',
    4: 'warning', 5: 'notice', 6: 'info', 7: 'debug'
}

def parse_syslog_message(message):
    """
    Robust syslog parser supporting RFC 3164, RFC 5424, and common variants.
    Returns a dict with all fields, always preserves raw_message.
    """
    raw_message = message
    result = {
        'timestamp': None,
        'hostname': None,
        'program': None,
        'severity': 'info',
        'raw_message': raw_message,
        'message': None,
        'structured_data': {},
    }
    
    # Try RFC 5424 first
    match = RFC5424_REGEX.match(message)
    if match:
        pri = int(match.group('pri'))
        result['severity'] = SEVERITY_MAP.get(pri & 0x07, 'info')
        result['timestamp'] = parse_flexible_timestamp(match.group('timestamp'))
        result['hostname'] = match.group('hostname')
        result['program'] = match.group('appname')
        result['message'] = match.group('message')
        # Structured data
        sd = match.group('structured_data')
        if sd and sd.strip():
            result['structured_data'] = {'sd': sd.strip()}
        # Add extra fields
        result['structured_data'].update({
            'priority': pri,
            'facility': (pri >> 3) & 0x1F,
            'severity_code': pri & 0x07,
            'procid': match.group('procid'),
            'msgid': match.group('msgid'),
        })
        return result
    
    # Try RFC 3164
    match = RFC3164_REGEX.match(message)
    if match:
        pri = int(match.group('pri'))
        result['severity'] = SEVERITY_MAP.get(pri & 0x07, 'info')
        result['timestamp'] = parse_flexible_timestamp(match.group('timestamp'))
        result['hostname'] = match.group('hostname')
        result['program'] = match.group('process')
        result['message'] = match.group('message')
        pid = match.group('pid')
        if pid:
            result['structured_data']['pid'] = int(pid)
        result['structured_data'].update({
            'priority': pri,
            'facility': (pri >> 3) & 0x1F,
            'severity_code': pri & 0x07,
        })
        return result
    
    # Try enhanced regex for problematic formats
    match = ENHANCED_REGEX.match(message)
    if match:
        pri = match.group('pri')
        if pri:
            pri = int(pri)
            result['severity'] = SEVERITY_MAP.get(pri & 0x07, 'info')
            result['structured_data'].update({
                'priority': pri,
                'facility': (pri >> 3) & 0x1F,
                'severity_code': pri & 0x07,
            })
        
        # Handle timestamp - if it's just time, use current date
        ts = match.group('timestamp')
        if ts:
            # If it's just time format (HH: MM:SS), add current date
            if re.match(r'\d{1,2}:\s+\d{2}:\d{2}', ts):
                current_date = datetime.now().strftime('%b %d')
                ts = f"{current_date} {ts.replace(' ', '')}"
            result['timestamp'] = parse_flexible_timestamp(ts)
        
        result['hostname'] = match.group('hostname')
        result['program'] = match.group('process')
        result['message'] = match.group('message')
        pid = match.group('pid')
        if pid:
            result['structured_data']['pid'] = int(pid)
        return result
    
    # Try no-priority regex
    match = NO_PRI_REGEX.match(message)
    if match:
        result['timestamp'] = parse_flexible_timestamp(match.group('timestamp'))
        result['hostname'] = match.group('hostname')
        result['program'] = match.group('process')
        result['message'] = match.group('message')
        pid = match.group('pid')
        if pid:
            result['structured_data']['pid'] = int(pid)
        return result
    
    # Fallback: just store the message
    match = FALLBACK_REGEX.match(message)
    if match:
        result['message'] = match.group('message')
    
    # Always set timestamp if missing
    if not result['timestamp']:
        result['timestamp'] = datetime.utcnow()
    
    return result

def parse_flexible_timestamp(ts):
    """
    Try to parse a syslog timestamp using dateutil for flexibility.
    Handles RFC 3164, RFC 5424, and common variants.
    """
    if not ts:
        return datetime.utcnow()
    try:
        # Try dateutil for full flexibility
        dt = dateutil_parser.parse(ts, fuzzy=True, default=datetime.now())
        # If year is missing (RFC 3164), set to current year
        if dt.year == 1900:
            dt = dt.replace(year=datetime.now().year)
        return dt
    except Exception:
        return datetime.utcnow()

def validate_syslog_message(message):
    """Validate if a message looks like a syslog message."""
    if not message:
        return False
    # Basic validation - should have some structure
    return len(message.strip()) > 0

def format_for_storage(parsed_message):
    """Format parsed message for database storage."""
    return {
        "timestamp": parsed_message["timestamp"],
        "hostname": parsed_message["hostname"],
        "message": parsed_message["message"],
        "severity": parsed_message.get("severity", "info"),
        "raw_message": parsed_message.get("raw_message", ""),
        "program": parsed_message.get("program"),
        "structured_data": parsed_message.get("structured_data", {})
    }

def clean_hostname(hostname):
    """
    Clean and validate hostname/IP address.
    Returns None if the hostname is clearly invalid.
    """
    if not hostname:
        return None
    
    # Remove any whitespace
    hostname = hostname.strip()
    
    # Check if it's a valid IP address pattern
    ip_pattern = re.compile(r'^(\d{1,3}\.){3}\d{1,3}$')
    if ip_pattern.match(hostname):
        return hostname
    
    # Check if it's a valid hostname pattern
    hostname_pattern = re.compile(r'^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$')
    if hostname_pattern.match(hostname):
        return hostname
    
    # If it's just a number (like "23"), it's probably not a valid hostname
    if hostname.isdigit():
        return None
    
    # For other cases, return as-is but log a warning
    return hostname