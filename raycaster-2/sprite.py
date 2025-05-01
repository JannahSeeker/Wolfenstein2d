# sprite.py
# Generic representation for server-controlled sprites (like enemies)
import math
from typing import Optional, Tuple
import config

class Sprite:
    def __init__(self, sprite_id: str, data: dict):
        self.id = sprite_id
        self.x: float = 0.0
        self.y: float = 0.0
        self.texture_name: str = "Unknown" # e.g., "EnemyTypeA", "Barrel"
        self.texture_index: int = 0 # Specific frame/variant
        self.health: Optional[int] = None # If applicable
        self.is_shooting: Optional[bool] = None # If applicable
        self.is_dead: Optional[bool] = None # If applicable
        self.scale: float = config.SPRITE_SCALE
        self.last_update_time: float = 0.0

        self.update_from_server(data)

    def update_from_server(self, data: dict):
        """Updates sprite state from server data."""
        self.x = data.get("x", self.x)
        self.y = data.get("y", self.y)
        self.texture_name = data.get("texture_name", self.texture_name)
        self.texture_index = data.get("texture_index", self.texture_index) # Server decides animation frame etc.
        self.health = data.get("health", self.health)
        self.is_shooting = data.get("is_shooting", self.is_shooting)
        self.is_dead = data.get("is_dead", self.is_dead)
        self.scale = data.get("scale", self.scale)
        # self.last_update_time = pr.get_time()

    def get_pos_tuple(self) -> Tuple[float, float]:
        return (self.x, self.y)

    def should_draw(self) -> bool:
        """Determines if the sprite should be drawn (e.g., not dead and collected)."""
        # Add logic here based on state, e.g.
        # if self.is_dead and self.texture_name != "Corpse": return False
        # For now, draw everything unless explicitly told 'is_dead' is True
        # and we decide dead sprites shouldn't render (or use a dead texture index)
        # return not self.is_dead if self.is_dead is not None else True
        return True # Draw all sprites for now