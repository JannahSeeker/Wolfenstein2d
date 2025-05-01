# remote_player.py
import math
from typing import Optional
from typing import Tuple
import config

class RemotePlayer:
    def __init__(self, player_id: str, data: dict):
        self.id = player_id
        self.x: float = 0.0
        self.y: float = 0.0
        self.angle: float = 0.0
        self.health: int = 100
        self.is_shooting: bool = False
        self.is_dead: bool = False
        self.is_running: bool = False
        self.is_walking: bool = False # Determine based on position change
        self.last_update_time: float = 0.0 # For interpolation or state detection
        self.last_x: float = 0.0
        self.last_y: float = 0.0
        self.sprite_name = "WinterGuard" # Could be sent by server if different player types

        self.update_from_server(data) # Initialize with first data packet

    def update_from_server(self, data: dict):
        """Updates the state of this remote player from server data."""
        new_x = data.get("x", self.x)
        new_y = data.get("y", self.y)

        # Determine if walking/running based on position change and server flag
        # Threshold check helps ignore minor network jitter if not interpolating
        pos_changed = abs(new_x - self.x) > 0.01 or abs(new_y - self.y) > 0.01

        self.is_running = data.get("is_running", False) and pos_changed
        self.is_walking = (not self.is_running) and pos_changed

        self.last_x = self.x
        self.last_y = self.y
        self.x = new_x
        self.y = new_y
        self.angle = data.get("angle", self.angle) # Angle needed to face sprite correctly
        self.health = data.get("health", self.health)
        self.is_shooting = data.get("is_shooting", False) # Might need timing/animation logic
        self.is_dead = data.get("is_dead", False)
        # Record update time if needed for interpolation (requires pr.get_time())
        # self.last_update_time = pr.get_time()

    def get_texture_index(self, player_angle_rad: float) -> int:
        """Determines the correct sprite index based on state and viewing angle."""
        if self.is_dead:
            # TODO: Add dead sprite index? For now, maybe just idle front.
             return config.SPRITE_WINTERGUARD_IDLE_START -1 # Use 0-based index

        # Calculate relative angle between observer and sprite's facing direction
        # For simplicity now, we'll base direction on the *observer's* view angle to the sprite
        # A better way is using the sprite's *own* angle from server data.

        # Angle from player (observer) to this remote player
        dx = self.x - player_pos[0]
        dy = self.y - player_pos[1]
        angle_to_sprite = math.atan2(dy, dx)

        # Angle difference between player's view and the vector to the sprite
        delta_angle = player_angle_rad - angle_to_sprite

        # Normalize angle difference to be between -pi and +pi
        while delta_angle <= -math.pi: delta_angle += 2 * math.pi
        while delta_angle > math.pi: delta_angle -= 2 * math.pi

        # Determine direction index (0-7) based on relative angle
        # 0: back, 2: right, 4: front, 6: left (approx)
        # We need to map our 1-8 texture scheme to this.
        # Texture 1 = front (facing camera). Let's map delta_angle around 0 to index 0 (for texture 1)
        # Texture 5 = back (facing away). Map delta_angle around +/- pi to index 4 (for texture 5)
        direction_index = int( (delta_angle + math.pi) / (2 * math.pi) * config.SPRITE_DIRECTIONS + 0.5 + config.SPRITE_DIRECTIONS // 2) % config.SPRITE_DIRECTIONS
        # This maps: 0 rad -> dir 4 (front), pi/-pi -> dir 0 (back), pi/2 -> dir 2 (left), -pi/2 -> dir 6 (right)
        # Let's remap to match WinterGuard_01 (front) = 0, clockwise
        # WinterGuard_01 = Front = dir 4 -> final index 0
        # WinterGuard_02 = Front-Right = dir 5 -> final index 1
        # WinterGuard_03 = Right = dir 6 -> final index 2
        # WinterGuard_04 = Back-Right = dir 7 -> final index 3
        # WinterGuard_05 = Back = dir 0 -> final index 4
        # WinterGuard_06 = Back-Left = dir 1 -> final index 5
        # WinterGuard_07 = Left = dir 2 -> final index 6
        # WinterGuard_08 = Front-Left = dir 3 -> final index 7
        remap = {4: 0, 5: 1, 6: 2, 7: 3, 0: 4, 1: 5, 2: 6, 3: 7}
        final_direction_index = remap.get(direction_index, 0) # Default to front

        # Determine state base index
        if self.is_running:
             base_index = config.SPRITE_WINTERGUARD_RUN_START
        elif self.is_walking:
            base_index = config.SPRITE_WINTERGUARD_WALK_START
        # elif self.is_shooting: # Add shooting state later if needed
        #     base_index = SHOOTING_START_INDEX
        else: # Idle
             base_index = config.SPRITE_WINTERGUARD_IDLE_START

        # Calculate final texture index (using 1-based indexing from files)
        # Texture index is 1-based, add direction offset
        texture_file_index = base_index + final_direction_index

        # Return 0-based index for list access in AssetsManager
        print("Calculated texture file index: ", texture_file_index)
        return texture_file_index - 1


# Global variable to hold player position and angle for texture calculation
# This is a simplification; passing player state explicitly is better practice
player_pos: Tuple = (0.0, 0.0)
player_angle_rad: float = 0.0

def set_observer_state(pos: Tuple, angle: float):
    """Updates the global observer state needed for sprite direction calculation."""
    global player_pos, player_angle_rad
    player_pos = pos
    player_angle_rad = angle