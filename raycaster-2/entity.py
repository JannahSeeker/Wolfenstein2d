# entity.py
# Representation for static/collectible entities like keys, chests
from typing import Tuple
import config

class Entity:
    def __init__(self, entity_id: str, data: dict):
        self.id = entity_id
        self.x: float = 0.0
        self.y: float = 0.0
        self.type: str = "Unknown" # e.g., "Key", "Chest", "HealthPack"
        self.texture_name: str = "DefaultEntity" # Asset name for this entity
        self.texture_index: int = 0 # Frame/variant if needed
        self.is_active: bool = True # e.g., set to False when picked up
        self.scale: float = config.SPRITE_SCALE * 0.8 # Slightly smaller maybe?

        self.update_from_server(data)

    def update_from_server(self, data: dict):
        """Updates entity state from server data."""
        # Usually only position and active status change
        self.x = data.get("x", self.x)
        self.y = data.get("y", self.y)
        self.type = data.get("type", self.type)
        self.texture_name = data.get("texture_name", self.texture_name)
        self.texture_index = data.get("texture_index", self.texture_index)
        self.is_active = data.get("is_active", self.is_active)
        self.scale = data.get("scale", self.scale)

    def get_pos_tuple(self) -> Tuple[float, float]:
        return (self.x, self.y)

    def should_draw(self) -> bool:
        """Determines if the entity should be drawn (e.g., is active)."""
        return self.is_active