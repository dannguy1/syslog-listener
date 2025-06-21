class SyslogServer:
    def __init__(self, host='0.0.0.0', port=514):
        self.host = host
        self.port = port
        self.server_socket = None

    def start(self):
        import socket
        import threading
        from utils.parser import parse_syslog_message
        from db.models import save_log_entry

        self.server_socket = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.server_socket.bind((self.host, self.port))
        print(f"Syslog server listening on {self.host}:{self.port}")

        while True:
            data, addr = self.server_socket.recvfrom(1024)
            log_message = data.decode('utf-8')
            print(f"Received message from {addr}: {log_message}")

            parsed_message = parse_syslog_message(log_message)
            save_log_entry(parsed_message)

    def stop(self):
        if self.server_socket:
            self.server_socket.close()
            print("Syslog server stopped.")