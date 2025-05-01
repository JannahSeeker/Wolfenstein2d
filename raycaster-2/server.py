# server.py
import socketserver
import threading
import json
import time
import uuid # To generate unique IDs (alternative to ip:port)
import math # <-- Added import
from typing import Dict, Any, Optional

try:
    from map import GameMap
except ImportError:
    print("Warning: map.py not found. Cannot load map data.")
    GameMap = None # Define as None if import fails

# Reuse configuration from the client side for host/port
try:
    import config
    SERVER_HOST = config.SERVER_IP # Use the IP specified in config
    SERVER_PORT = config.SERVER_PORT
    print(f"Server Configuration: Host={SERVER_HOST}, Port={SERVER_PORT}")
except ImportError:
    print("Warning: config.py not found. Using default server settings.")
    SERVER_HOST = "127.0.0.1"
    SERVER_PORT = 5555
    # Define a minimal map if config isn't available
    DEFAULT_MAP_GRID = [
        [1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
        [1, 0, 0, 0, 2, 0, 0, 0, 0, 1],
        [1, 0, 1, 0, 0, 0, 1, 0, 0, 1],
        [1, 0, 2, 0, 0, 0, 3, 0, 0, 1],
        [1, 0, 0, 0, 0, 0, 0, 0, 0, 1],
        [1, 0, 0, 0, 3, 0, 0, 0, 0, 1],
        [1, 0, 0, 0, 1, 0, 1, 0, 0, 1],
        [1, 0, 2, 0, 0, 0, 2, 0, 0, 1],
        [1, 0, 0, 0, 0, 0, 0, 0, 0, 1],
        [1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
    ]


# --- Global Server State ---
# Thread-safe access needed if modifying complex structures concurrently.
# For simple dict updates on player states, Python's GIL provides some safety,
# but a lock is better practice for adding/removing clients.
server_state_lock = threading.Lock()
# Maps client_id to its handler instance (for sending data)
connected_clients: Dict[str, 'ClientHandler'] = {}
# Maps client_id to the latest player state dictionary received
player_states: Dict[str, Dict[str, Any]] = {}
# Static map data (load from config or file ideally)
game_map_data = {"grid": []} # Default empty map
if GameMap: # Check if import succeeded
    try:
        # Use the imported GameMap class correctly
        game_map_data = {"grid": GameMap().grid}
        print("Loaded map data from map.GameMap")
    except Exception as e:
        print(f"Error loading map data from GameMap: {e}")
elif 'DEFAULT_MAP_GRID' in locals(): # Fallback if GameMap failed but config fallback worked
     game_map_data = {"grid": DEFAULT_MAP_GRID}
     print("Using default map grid due to import/config issues.")
else:
     print("Warning: Could not load map data.")

# Get player start position from config if possible, otherwise use defaults
try:
    player_start_x = config.PLAYER_START_X
    player_start_y = config.PLAYER_START_Y
    player_start_angle = config.PLAYER_START_ANGLE # Might be useful
except (NameError, AttributeError):
    player_start_x = 3.5
    player_start_y = 3.5
    player_start_angle = 0.0

# DEBUG: Place sprite 2 units in front of player start
debug_sprite_x = player_start_x + 2.0 * math.cos(player_start_angle)
debug_sprite_y = player_start_y + 2.0 * math.sin(player_start_angle)
print(f"Debug sprite ('sprite_guard_npc') placed at: ({debug_sprite_x:.2f}, {debug_sprite_y:.2f})")

# Basic example sprites/entities (server dictates these)
sprite_states: Dict[str, Dict[str, Any]] = {
    # "sprite_barrel_1": {"id": "sprite_barrel_1", "x": 5.5, "y": 2.5, "texture_name": "Barrel", "texture_index": 0, "scale": 0.6},
    # --- MODIFIED POSITION ---
    "sprite_guard_npc": {
        "id": "sprite_guard_npc",
        "x": debug_sprite_x, # Set X for debugging
        "y": debug_sprite_y, # Set Y for debugging
        "texture_name": "WinterGuard",
        "texture_index": 1,
        "scale": 1,
        "health": 50
        }
}
entity_states: Dict[str, Dict[str, Any]] = {
     # "entity_key_1": {"id": "entity_key_1", "x": 2.5, "y": 2.5, "type": "Key", "texture_name": "Key", "texture_index": 0, "is_active": True, "scale": 0.5},
     # "entity_chest_1": {"id": "entity_chest_1", "x": 8.5, "y": 1.5, "type": "Chest", "texture_name": "Chest", "texture_index": 0, "is_active": True, "scale": 0.8}
}
# ---------------------------


class ClientHandler(socketserver.BaseRequestHandler):
    """Handles communication with a single client."""
    client_id: str = None
    buffer: str = "" # Buffer for partial messages

    def setup(self):
        """Called when a new client connects."""
        self.client_id = str(uuid.uuid4()) # More robust ID
        print(f"Client connected: {self.client_address}, assigned ID: {self.client_id}")

        with server_state_lock:
            connected_clients[self.client_id] = self
            # Initialize player state (client will send its actual starting state)
            # Use the actual player start coordinates from config/defaults
            player_states[self.client_id] = {
                "x": player_start_x, "y": player_start_y, "angle": player_start_angle,
                "health": config.PLAYER_HEALTH_START if 'config' in globals() else 100,
                "is_shooting": False, "is_dead": False, "is_running": False
            }

        # 1. Send handshake acknowledgment  1 with the client's new ID
        handshake_msg = {"type": "handshake_ack", "payload": {"client_id": self.client_id}}
        self.send_message(handshake_msg)

        # 2. Send the initial full game state
        full_state = self.get_full_game_state()
        initial_state_msg = {"type": "game_state_full", "payload": full_state}
        self.send_message(initial_state_msg)

        # 3. Notify *other* clients about the new connection
        new_player_update = {
             "players": {self.client_id: player_states[self.client_id]} # Send initial actual state
        }
        broadcast_message({"type": "game_state_update", "payload": new_player_update}, exclude_client_id=self.client_id)


    def handle(self):
        """Main loop to receive data from the client."""
        try:
            while True:
                data = self.request.recv(4096).decode('utf-8')
                if not data:
                    print(f"Client {self.client_id} disconnected (no data).")
                    break

                self.buffer += data
                while '\n' in self.buffer:
                    message_str, self.buffer = self.buffer.split('\n', 1)
                    if message_str:
                        try:
                            message = json.loads(message_str)
                            self.process_message(message)
                        except json.JSONDecodeError:
                            print(f"Warning: Received invalid JSON from {self.client_id}: {message_str}")
                        except Exception as e:
                             print(f"Error processing message from {self.client_id}: {e}")

        except ConnectionResetError:
            print(f"Client {self.client_id} connection reset.")
        except Exception as e:
            print(f"Error in handler for {self.client_id}: {e}")
        finally:
            pass # Cleanup is handled in finish()


    def finish(self):
        """Called when the client disconnects or handle() exits."""
        if not self.client_id: return # Avoid issues if setup failed partially
        print(f"Cleaning up connection for client {self.client_id} ({self.client_address}).")
        with server_state_lock:
            if self.client_id in connected_clients:
                del connected_clients[self.client_id]
            if self.client_id in player_states:
                del player_states[self.client_id]

        disconnect_payload = {"client_id": self.client_id}
        broadcast_message({"type": "player_disconnect", "payload": disconnect_payload}, exclude_client_id=self.client_id)


    def process_message(self, message: Dict[str, Any]):
        """Handles specific message types from the client."""
        msg_type = message.get("type")
        payload = message.get("payload")

        if msg_type == "player_update" and payload:
            with server_state_lock:
                 if self.client_id in player_states:
                    player_states[self.client_id].update(payload)
                 else:
                     player_states[self.client_id] = payload # Should not happen

            update_payload = { "players": {self.client_id: payload} }
            # --- TODO: Server side logic here ---
            # Validate movement, check shooting hits, update health, NPC AI etc.
            # For now, just relay the state.
            # Example: Check if player shot the debug sprite
            # if payload.get("is_shooting"):
            #    player_pos = (payload.get("x"), payload.get("y"))
            #    player_angle = payload.get("angle")
            #    with server_state_lock: # Lock needed to access sprite_states potentially
            #         hit_sprite_id = check_shot_hit(player_pos, player_angle, sprite_states)
            #         if hit_sprite_id == "sprite_guard_npc":
            #             print("Player shot the debug sprite!")
            #             # Modify sprite state (e.g., health) and include in update_payload
            #             if "sprites" not in update_payload: update_payload["sprites"] = {}
            #             sprite_states[hit_sprite_id]["health"] -= 10
            #             update_payload["sprites"][hit_sprite_id] = {"health": sprite_states[hit_sprite_id]["health"]}


            broadcast_message({"type": "game_state_update", "payload": update_payload}, exclude_client_id=self.client_id)

        elif msg_type == "request_map":
             map_msg = {"type": "map_update", "payload": game_map_data}
             self.send_message(map_msg)
        else:
            print(f"Warning: Received unhandled message type '{msg_type}' from {self.client_id}")


    def send_message(self, message: Dict[str, Any]):
        """Sends a JSON message to this specific client."""
        if not self.request._closed: # Check if socket is still open
            try:
                json_message = json.dumps(message) + '\n'
                self.request.sendall(json_message.encode('utf-8'))
            except OSError as e:
                print(f"Error sending message to {self.client_id}: {e}")
            except Exception as e:
                 print(f"Error encoding or sending message to {self.client_id}: {e}")


    def get_full_game_state(self) -> Dict[str, Any]:
        """Constructs the complete current game state."""
        with server_state_lock:
            # Create copies to avoid potential modification during iteration/sending
            current_player_states = {pid: pdata.copy() for pid, pdata in player_states.items()}
            current_sprite_states = {sid: sdata.copy() for sid, sdata in sprite_states.items()}
            current_entity_states = {eid: edata.copy() for eid, edata in entity_states.items()}

        return {
            "map": game_map_data,
            "players": current_player_states,
            "sprites": current_sprite_states,
            "entities": current_entity_states,
        }


def broadcast_message(message: Dict[str, Any], exclude_client_id: Optional[str] = None):
    """Sends a message to all connected clients, optionally excluding one."""
    with server_state_lock:
        client_ids = list(connected_clients.keys()) # Copy keys for safe iteration

    for cid in client_ids:
        if cid != exclude_client_id:
            handler = None
            with server_state_lock:
                 handler = connected_clients.get(cid) # Get handler safely

            if handler:
                handler.send_message(message) # Handler method handles potential errors


class ThreadedTCPServer(socketserver.ThreadingMixIn, socketserver.TCPServer):
    """A TCP server that handles each client in a separate thread."""
    daemon_threads = True
    allow_reuse_address = True


if __name__ == "__main__":
    print("Starting Python Raycaster Test Server...")
    server = ThreadedTCPServer((SERVER_HOST, SERVER_PORT), ClientHandler)
    print(f"Server listening on {SERVER_HOST}:{SERVER_PORT}")

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nServer shutting down by request...")
    finally:
        server.shutdown()
        server.server_close()
        print("Server shutdown complete.")