# player.py
import pyray as pr
import math
import config
from map import GameMap # Import GameMap for collision detection
from typing import Tuple

class Player:
    def __init__(self, x: float, y: float, angle: float):
        self.x = x
        self.y = y
        self.angle = angle # Radians
        self.health = config.PLAYER_HEALTH_START
        self.is_shooting = False
        self.is_dead = False
        self.is_running = False
        self.delta_time = 0.0 # Will be updated each frame

    def handle_input(self, game_map: GameMap):
        """Processes player input for movement and actions."""
        if self.is_dead:
            return

        move_speed = config.PLAYER_MOVE_SPEED
        rot_speed = config.PLAYER_ROTATION_SPEED * self.delta_time

        # Rotation
        if pr.is_key_down(pr.KeyboardKey.KEY_LEFT) or pr.is_key_down(pr.KeyboardKey.KEY_A):
            self.angle -= rot_speed
        if pr.is_key_down(pr.KeyboardKey.KEY_RIGHT) or pr.is_key_down(pr.KeyboardKey.KEY_D):
            self.angle += rot_speed

        # Ensure angle stays within 0 to 2*PI
        self.angle = self.angle % (2 * math.pi)
        if self.angle < 0:
            self.angle += (2 * math.pi)

        # Movement Speed (Running)
        self.is_running = pr.is_key_down(pr.KeyboardKey.KEY_LEFT_SHIFT) or pr.is_key_down(pr.KeyboardKey.KEY_RIGHT_SHIFT)
        if self.is_running:
             move_speed *= config.PLAYER_RUN_MULTIPLIER

        move_step = move_speed * self.delta_time
        move_x = 0.0
        move_y = 0.0

        # Forward/Backward Movement
        if pr.is_key_down(pr.KeyboardKey.KEY_UP) or pr.is_key_down(pr.KeyboardKey.KEY_W):
            move_x += math.cos(self.angle) * move_step
            move_y += math.sin(self.angle) * move_step
        if pr.is_key_down(pr.KeyboardKey.KEY_DOWN) or pr.is_key_down(pr.KeyboardKey.KEY_S):
            move_x -= math.cos(self.angle) * move_step
            move_y -= math.sin(self.angle) * move_step

        # Strafing (Optional - add if desired)
        # angle_strafe = self.angle + math.pi / 2.0
        # if pr.is_key_down(pr.KeyboardKey.KEY_Q): # Strafe Left
        #     move_x -= math.cos(angle_strafe) * move_step
        #     move_y -= math.sin(angle_strafe) * move_step
        # if pr.is_key_down(pr.KeyboardKey.KEY_E): # Strafe Right
        #     move_x += math.cos(angle_strafe) * move_step
        #     move_y += math.sin(angle_strafe) * move_step

        # Simple Collision Detection (check target position before moving)
        target_x = self.x + move_x
        target_y = self.y + move_y

        # Check collision separately for X and Y for smoother sliding against walls
        if not game_map.is_wall(target_x, self.y):
            self.x = target_x
        if not game_map.is_wall(self.x, target_y):
            self.y = target_y

        # Shooting (simple toggle for now)
        if pr.is_mouse_button_pressed(pr.MouseButton.MOUSE_BUTTON_LEFT):
             self.is_shooting = True # Server should handle cooldown/ammo
        else:
             # This might need refinement - maybe only set to false after server ack?
             # Or based on animation duration? For now, just reset if not pressed.
             # A better approach is often making is_shooting True for one frame on press.
             self.is_shooting = False # Reset shooting state

    def update(self, delta_time: float, game_map: GameMap):
        """Updates player state based on input and time."""
        self.delta_time = delta_time
        # Handle input only if not dead
        if not self.is_dead:
            self.handle_input(game_map)

        # Update dead state based on health (server will likely be the authority)
        if self.health <= 0:
            self.is_dead = True
            # Potentially trigger respawn logic here or wait for server command

    def get_state_dict(self) -> dict:
        """Returns player state in a format suitable for sending over network."""
        return {
            "x": round(self.x, 4),
            "y": round(self.y, 4),
            "angle": round(self.angle, 4),
            "health": self.health,
            "is_shooting": self.is_shooting,
            "is_dead": self.is_dead,
            "is_running": self.is_running # Send running state for sprite animation
            # Add other relevant state like weapon, ammo, etc. later
        }

    def apply_server_update(self, data: dict):
        """Applies authoritative state updates from the server (e.g., health)."""
        # Important: Avoid directly setting position/angle if server doesn't correct it,
        # unless implementing server reconciliation. Usually, server only sends corrections
        # or health/death status.
        self.health = data.get("health", self.health)
        self.is_dead = data.get("is_dead", self.is_dead)
        # Potentially server could force position if cheating detected or on spawn:
        # self.x = data.get("x", self.x)
        # self.y = data.get("y", self.y)
        # self.angle = data.get("angle", self.angle)

    def get_pos_tuple(self) -> Tuple[float, float]:
        return (self.x, self.y)

    def get_dir_vector(self) -> Tuple[float, float]:
        return (math.cos(self.angle), math.sin(self.angle))

    def get_plane_vector(self) -> Tuple[float, float]:
        """
        Returns the camera plane vector.
        This version uses the definition common in many raycasting tutorials
        (e.g., LodeV), directly relating plane to direction components.
        The scaling factor (0.66) determines the field of view.
        """
        dir_x = math.cos(self.angle)
        dir_y = math.sin(self.angle)
        # Common FOV scaling factor (approx 90 degrees horizontal)
        # Adjust this value to change the FOV if needed
        scale = 0.66

        # Calculate plane vector components based on direction
        # plane_x = -dir_y * scale
        # plane_y = dir_x * scale
        # OR the other perpendicular:
        plane_x = -dir_y * scale
        plane_y = dir_x * scale

        return (plane_x, plane_y)