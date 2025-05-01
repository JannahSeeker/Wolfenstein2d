# main.py
from typing import Optional
import pyray as pr
import time
import config

# Import game components
from assets_manager import AssetsManager
from map import GameMap
from player import Player
from remote_player import RemotePlayer # Only the class needed here
from sprite import Sprite
from entity import Entity
from network import NetworkClient
from renderer import Renderer

class Game:
    def __init__(self):
        # Initialization
        pr.init_window(config.SCREEN_WIDTH, config.SCREEN_HEIGHT, "Python Raycaster Multiplayer")
        pr.set_target_fps(config.TARGET_FPS)
        # pr.hide_cursor() # Optional: Hide cursor during gameplay

        self.assets_manager = AssetsManager()
        self.game_map = GameMap()
        self.player = Player(config.PLAYER_START_X, config.PLAYER_START_Y, config.PLAYER_START_ANGLE)
        self.network_client = NetworkClient()
        self.renderer = Renderer(self.assets_manager)

        # Game State Management
        self.remote_players: dict[str, RemotePlayer] = {}
        self.sprites: dict[str, Sprite] = {}
        self.entities: dict[str, Entity] = {}
        self.game_state = config.STATE_CONNECTING # Start in connecting state
        self.client_id: Optional[str] = None # Assigned by server upon connection

        # Timing for network updates
        self.last_network_send_time = 0.0

    def load_content(self):
        """Load game assets."""
        self.assets_manager.load_assets()
        # TODO: Load map data from server or file if needed
        # self.game_map.load_from_file("map.txt")

    def unload_content(self):
        """Unload game assets."""
        self.assets_manager.unload_assets()

    def run(self):
        """Main game loop."""
        self.load_content()

        while not pr.window_should_close():
            # Get frame time for physics/movement calculations
            delta_time = pr.get_frame_time()

            # --- Update ---
            self.update(delta_time)

            # --- Draw ---
            self.renderer.draw_frame(self.player, self.game_map, self.remote_players, self.sprites, self.entities)

        self.shutdown()

    def update(self, delta_time: float):
        """Handles all game logic updates for a frame."""

        # Handle Network Updates (Receive)
        if self.network_client.connected:
            server_messages = self.network_client.receive_data()
            self.process_server_messages(server_messages)
        elif self.game_state != config.STATE_CONNECTING:
            # If disconnected unexpectedly, maybe try reconnecting or go to a menu
            print("Connection lost. Attempting to reconnect...")
            self.game_state = config.STATE_CONNECTING


        # Update based on Game State
        if self.game_state == config.STATE_CONNECTING:
            if self.network_client.connect():
                 # Connection successful, wait for server handshake (e.g., client ID assignment)
                 # For now, just switch to playing - server needs to send initial state
                 print("Connected. Waiting for server state...")
                 # Assume server will send initial state shortly
                 self.game_state = config.STATE_PLAYING # Or a STATE_LOADING if needed
            else:
                # Failed connection, maybe show an error message, wait and retry?
                # For now, we just keep trying in the loop. Add delay?
                 time.sleep(1.0) # Wait before retrying

        elif self.game_state == config.STATE_PLAYING:
            # Update local player (input and movement)
            self.player.update(delta_time, self.game_map)

            # Update other game logic if needed (e.g., local effects)

            # Handle Network Updates (Send)
            current_time = time.time()
            if self.network_client.connected and (current_time - self.last_network_send_time >= config.NETWORK_UPDATE_RATE):
                player_state = self.player.get_state_dict()
                self.network_client.send_data({
                    "type": "player_update",
                    "payload": player_state
                })
                self.last_network_send_time = current_time
                # Reset one-shot flags after sending
                if self.player.is_shooting: self.player.is_shooting = False


        elif self.game_state == config.STATE_GAME_OVER:
            # Handle game over logic (e.g., wait for input to restart/quit)
            if pr.is_key_pressed(pr.KeyboardKey.KEY_ENTER):
                self.reset_game() # Example reset function

        # --- Check for connection loss outside receive block ---
        if not self.network_client.connected and self.game_state == config.STATE_PLAYING:
             print("Lost connection during gameplay.")
             self.game_state = config.STATE_CONNECTING # Try to reconnect


    def process_server_messages(self, messages: list[dict[str, any]]):
        """Processes messages received from the server."""
        for msg in messages:
            msg_type = msg.get("type")
            payload = msg.get("payload")

            if not msg_type or not payload:
                print(f"Warning: Received malformed message: {msg}")
                continue

            # print(f"Processing server message: {msg_type}") # Debug

            if msg_type == "handshake_ack":
                # Server acknowledges connection and assigns an ID
                self.client_id = payload.get("client_id")
                print(f"Handshake complete. Client ID: {self.client_id}")
                # Possibly request full game state here or server sends it automatically

            elif msg_type == "game_state_full":
                # Initial full state or major update
                self.update_full_game_state(payload)

            elif msg_type == "game_state_update":
                # Incremental update
                self.update_incremental_game_state(payload)

            elif msg_type == "player_disconnect":
                # Another player disconnected
                player_id = payload.get("client_id")
                if player_id and player_id in self.remote_players:
                    print(f"Player {player_id} disconnected.")
                    del self.remote_players[player_id]

            elif msg_type == "entity_update": # Example for single entity change
                 entity_id = payload.get("id")
                 if entity_id and entity_id in self.entities:
                     self.entities[entity_id].update_from_server(payload)
                 else: # New entity perhaps?
                     self.entities[entity_id] = Entity(entity_id, payload)


            elif msg_type == "map_update":
                 self.game_map.update_map(payload.get("grid", []))

            elif msg_type == "player_state_correction":
                 # Server corrects local player state (e.g. health, death, possibly pos)
                 self.player.apply_server_update(payload)
                 if self.player.is_dead and self.game_state != config.STATE_GAME_OVER:
                      print("Player died.")
                      self.game_state = config.STATE_GAME_OVER


            # Add more message types as needed (chat, item pickups, etc.)
            else:
                print(f"Warning: Received unknown message type: {msg_type}")

    def update_full_game_state(self, state: dict[str, any]):
        """Applies a complete game state snapshot from the server."""
        print("Applying full game state from server...")
        # Update map (optional, if map can change)
        if "map" in state and "grid" in state["map"]:
            self.game_map.update_map(state["map"]["grid"])

        # Update local player's authoritative state (health, maybe position on spawn)
        if self.client_id and self.client_id in state.get("players", {}):
            self.player.apply_server_update(state["players"][self.client_id])

        # Update remote players
        remote_players_data = state.get("players", {})
        current_remote_ids = set(self.remote_players.keys())
        server_remote_ids = set(remote_players_data.keys()) - {self.client_id} # Exclude self

        # Add/Update players present in server state
        for pid in server_remote_ids:
            if pid in self.remote_players:
                self.remote_players[pid].update_from_server(remote_players_data[pid])
            else:
                print(f" Adding new remote player: {pid}")
                self.remote_players[pid] = RemotePlayer(pid, remote_players_data[pid])

        # Remove players no longer present in server state
        for pid in current_remote_ids - server_remote_ids:
            print(f" Removing stale remote player: {pid}")
            del self.remote_players[pid]


        # Update generic sprites
        sprites_data = state.get("sprites", {})
        current_sprite_ids = set(self.sprites.keys())
        server_sprite_ids = set(sprites_data.keys())

        for sid in server_sprite_ids:
             if sid in self.sprites:
                 self.sprites[sid].update_from_server(sprites_data[sid])
             else:
                  print(f" Adding new sprite: {sid}")
                  self.sprites[sid] = Sprite(sid, sprites_data[sid])
        for sid in current_sprite_ids - server_sprite_ids:
             print(f" Removing stale sprite: {sid}")
             del self.sprites[sid]


        # Update entities
        entities_data = state.get("entities", {})
        current_entity_ids = set(self.entities.keys())
        server_entity_ids = set(entities_data.keys())

        for eid in server_entity_ids:
             if eid in self.entities:
                 self.entities[eid].update_from_server(entities_data[eid])
             else:
                  print(f" Adding new entity: {eid}")
                  self.entities[eid] = Entity(eid, entities_data[eid])
        for eid in current_entity_ids - server_entity_ids:
             print(f" Removing stale entity: {eid}")
             del self.entities[eid]

        # Ensure playing state if we received a full update
        if self.game_state != config.STATE_GAME_OVER: # Don't override game over
             self.game_state = config.STATE_PLAYING


    def update_incremental_game_state(self, update_data: dict[str, any]):
        """Applies partial updates to the game state."""
        # Update specific players
        player_updates = update_data.get("players", {})
        for pid, pdata in player_updates.items():
            if pid == self.client_id:
                self.player.apply_server_update(pdata)
                if self.player.is_dead and self.game_state != config.STATE_GAME_OVER:
                     print("Player died (incremental update).")
                     self.game_state = config.STATE_GAME_OVER
            elif pid in self.remote_players:
                self.remote_players[pid].update_from_server(pdata)
            else: # New player joined mid-game
                 print(f" New player joined (incremental): {pid}")
                 self.remote_players[pid] = RemotePlayer(pid, pdata)

        # Update specific sprites
        sprite_updates = update_data.get("sprites", {})
        for sid, sdata in sprite_updates.items():
             if sid in self.sprites:
                 self.sprites[sid].update_from_server(sdata)
             else:
                  print(f" New sprite added (incremental): {sid}")
                  self.sprites[sid] = Sprite(sid, sdata)

        # Update specific entities
        entity_updates = update_data.get("entities", {})
        for eid, edata in entity_updates.items():
             if eid in self.entities:
                 self.entities[eid].update_from_server(edata)
             else:
                  print(f" New entity added (incremental): {eid}")
                  self.entities[eid] = Entity(eid, edata)

        # Handle removals (server might send a specific removal message or just stop sending updates for that ID)
        # Handling removals via dedicated messages (like 'player_disconnect') is more robust.

    def reset_game(self):
        """Resets the game state (e.g., after death)."""
        print("Resetting game...")
        self.player = Player(config.PLAYER_START_X, config.PLAYER_START_Y, config.PLAYER_START_ANGLE)
        # Clear dynamic objects (server should resend them)
        self.remote_players.clear()
        self.sprites.clear()
        self.entities.clear()
        # Re-request state from server or wait for it? Best practice: server sends state on respawn command.
        # For now, just go back to playing/connecting state
        self.game_state = config.STATE_CONNECTING # Or STATE_PLAYING if server auto-sends state

    def shutdown(self):
        """Cleans up resources before exiting."""
        print("Shutting down...")
        self.unload_content()
        if self.network_client.connected:
            self.network_client.disconnect()
        pr.close_window()
        print("Shutdown complete.")


if __name__ == "__main__":
    game = Game()
    try:
        game.run()
    except Exception as e:
        print(f"\n--- FATAL ERROR ---")
        import traceback
        traceback.print_exc()
        print(f"-------------------\n")
    finally:
        # Ensure cleanup happens even if error occurs in run loop
        if 'game' in locals() and pr.is_window_ready():
             game.shutdown()