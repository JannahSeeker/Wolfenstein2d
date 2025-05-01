# network.py
import socket
import json
import time
import config
from typing import Optional, Dict, Any, List

class NetworkClient:
    def __init__(self):
        self.client = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.server_ip = config.SERVER_IP
        self.server_port = config.SERVER_PORT
        self.connected = False
        self.buffer = "" # Buffer for receiving partial messages

    def connect(self) -> bool:
        """Attempts to connect to the server."""
        try:
            print(f"Attempting to connect to {self.server_ip}:{self.server_port}...")
            self.client.settimeout(2.0) # Timeout for connection attempt
            self.client.connect((self.server_ip, self.server_port))
            self.client.settimeout(config.SOCKET_TIMEOUT) # Set to non-blocking/short timeout for recv
            # Optional: Send an initial handshake message
            # self.send_data({"type": "connect", "player_name": "Player"})
            self.connected = True
            print("Connection successful.")
            return True
        except socket.timeout:
             print("Connection attempt timed out.")
             self.connected = False
             return False
        except socket.error as e:
            print(f"Connection failed: {e}")
            self.connected = False
            return False

    def send_data(self, data: Dict[str, Any]):
        """Sends Python dictionary data to the server as JSON."""
        if not self.connected:
            print("Error: Not connected to server.")
            return

        try:
            message = json.dumps(data) + '\n' # Add newline as delimiter
            self.client.sendall(message.encode('utf-8'))
            # print(f"Sent: {message.strip()}") # Debug
        except socket.error as e:
            print(f"Network send error: {e}")
            self.connected = False # Assume disconnect on send error
        except Exception as e:
            print(f"Error encoding or sending data: {e}")


    def receive_data(self) -> List[Dict[str, Any]]:
        """Receives data from the server, handling non-blocking and message framing."""
        if not self.connected:
            return []

        messages = []
        try:
            # Keep receiving small chunks until a socket timeout (no more data currently)
            while True:
                 chunk = self.client.recv(4096).decode('utf-8')
                 if not chunk:
                      # Empty chunk usually means server disconnected gracefully
                      print("Server disconnected.")
                      self.connected = False
                      return [] # Return empty list, signal disconnection upstream

                 self.buffer += chunk
                 # Process complete messages (delimited by newline)
                 while '\n' in self.buffer:
                    message_str, self.buffer = self.buffer.split('\n', 1)
                    if message_str:
                        try:
                            message_dict = json.loads(message_str)
                            messages.append(message_dict)
                            # print(f"Recv: {message_dict}") # Debug
                        except json.JSONDecodeError:
                             print(f"Warning: Received invalid JSON: {message_str}")
        except socket.timeout:
            # This is expected in non-blocking mode when no data is available
            pass
        except socket.error as e:
            # Handle other socket errors (e.g., connection reset)
             if e.errno == 104: # Connection reset by peer
                 print("Server connection lost (reset by peer).")
             elif e.errno == 11: # Resource temporarily unavailable (EAGAIN/EWOULDBLOCK)
                 # This can happen instead of timeout sometimes
                  pass # Ignore, just means no data right now
             else:
                 print(f"Network receive error: {e}")
             self.connected = False # Assume disconnect on error
        except Exception as e:
            print(f"Error decoding received data: {e}")
            # Potentially corrupt data, maybe clear buffer?
            # self.buffer = ""

        return messages


    def disconnect(self):
        """Closes the connection to the server."""
        if self.connected:
            print("Disconnecting from server...")
            try:
                 # Optional: Send a disconnect message
                 self.send_data({"type": "disconnect"})
                 # Wait briefly to allow message to send? Not strictly needed with TCP.
                 # time.sleep(0.1)
                 self.client.shutdown(socket.SHUT_RDWR) # Graceful shutdown
            except socket.error as e:
                 print(f"Error during shutdown: {e}")
            finally:
                self.client.close()
                self.connected = False
                print("Disconnected.")
        # Recreate socket for potential reconnection
        self.client = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.buffer = ""