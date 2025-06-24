#!/usr/bin/env python3
"""
Test script to verify syslog message parsing
"""

import sys
import os
sys.path.append(os.path.join(os.path.dirname(__file__), 'src'))

from utils.parser import parse_syslog_message

def test_parser():
    """Test the parser with various syslog message formats."""
    
    test_messages = [
        # Standard format with priority
        "<134>Dec 15 10:30:45 testhost sshd[1234]: Failed password for user admin",
        
        # Standard format without priority
        "Dec 15 10:30:45 testhost sshd[1234]: Failed password for user admin",
        
        # Process with complex name
        "Dec 15 10:30:45 testhost /usr/sbin/ntpclient[5678]: Time synchronized",
        
        # Process with dots and hyphens
        "Dec 15 10:30:45 testhost systemd-udevd[9012]: Processing device",
        
        # Simple process name
        "Dec 15 10:30:45 testhost dnsmasq: exiting on receipt of SIGTERM",
        
        # Process with PID but no brackets
        "Dec 15 10:30:45 testhost kernel: key mismatch: pktlist key 16635 elem key 20731",
        
        # Real examples from your syslog.txt
        "Jun 20 18:07:02 miniupnpd[3227]: Invalid Callback in SUBSCRIBE <http://192.168.10.82:2869/upnp/eventing/jurkesulrl>",
        "Jun 20 18:07:55 wlceventd: wlceventd_proc_event(464): eth6: Deauth_ind 9A:EB:8A:3F:C4:C0, status: 0, reason: Disassociated due to inactivity (4)",
        "Jun 20 18:20:44 kernel: key mismatch: pktlist key 16635 elem key 20731",
        "Jun 21 02:25:09 WATCHDOG: [FAUPGRADE][auto_firmware_check:(6193)]retrieve firmware information",
        "Jun 21 08:07:44 rc_service: httpd 1413:notify_rc restart_logger",
    ]
    
    print("Testing Syslog Parser")
    print("=" * 50)
    
    for i, message in enumerate(test_messages, 1):
        print(f"\nTest {i}: {message}")
        print("-" * 40)
        
        parsed = parse_syslog_message(message)
        
        print(f"Timestamp: {parsed['timestamp']}")
        print(f"Hostname: {parsed['hostname']}")
        print(f"Process: {parsed['program']}")
        print(f"Severity: {parsed['severity']}")
        print(f"Message: {parsed['message']}")
        print(f"Structured Data: {parsed['structured_data']}")
        
        # Highlight the key issue - process name extraction
        if parsed['program']:
            print(f"✅ Process name extracted: '{parsed['program']}'")
        else:
            print(f"❌ Process name extraction failed")

if __name__ == "__main__":
    test_parser() 