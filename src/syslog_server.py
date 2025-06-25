import socket
import threading
import logging
from .utils.parser import parse_syslog_message
from .db.models import save_log_entry

class SyslogServer:
    def __init__(self, host='0.0.0.0', port=514):
        self.host = host
        self.port = port
        self.server_socket = None
        self.logger = logging.getLogger(__name__)
        self.running = False
        self.message_count = 0

    def start(self):
        try:
            self.server_socket = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            self.server_socket.bind((self.host, self.port))
            self.running = True
            self.logger.info(f"Syslog server listening on {self.host}:{self.port}")

            while self.running:
                try:
                    data, addr = self.server_socket.recvfrom(1024)
                    log_message = data.decode('utf-8')
                    
                    # Only log every 100th message to reduce verbosity
                    self.message_count += 1
                    if self.message_count % 100 == 1:
                        self.logger.info(f"Processing message #{self.message_count} from {addr}")
                    
                    # Log at debug level for individual messages (won't appear in normal operation)
                    self.logger.debug(f"Received message from {addr}: {log_message}")

                    parsed_message = parse_syslog_message(log_message)
                    save_log_entry(parsed_message)
                    
                    # Log successful saves every 100 messages
                    if self.message_count % 100 == 0:
                        self.logger.info(f"Processed {self.message_count} messages successfully")
                        
                except Exception as e:
                    self.logger.error(f"Error processing message: {e}")
                    
        except Exception as e:
            self.logger.error(f"Failed to start syslog server: {e}")
            raise

    def stop(self):
        self.running = False
        if self.server_socket:
            self.server_socket.close()
            self.logger.info(f"Syslog server stopped. Total messages processed: {self.message_count}")