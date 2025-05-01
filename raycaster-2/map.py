# map.py
from typing import List, Tuple

class GameMap:
    #modify this to 3dimensional height
    def __init__(self):
        # Example map - 0 = empty space, >0 = wall texture ID
        self.grid: List[List[int]] = [
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
        self.width = len(self.grid[0]) if self.grid else 0
        self.height = len(self.grid) if self.grid else 0

    def get_tile(self, x: int, y: int) -> int:
        """Gets the tile ID at integer map coordinates."""
        if 0 <= x < self.width and 0 <= y < self.height:
            return self.grid[y][x]
        return -1 # Return -1 for out of bounds

    def is_wall(self, x: float, y: float) -> bool:
        """Checks if the given world coordinates are inside a wall."""
        map_x = int(x)
        map_y = int(y)
        tile = self.get_tile(map_x, map_y)
        return tile > 0 # Any tile ID > 0 is considered a wall

    def update_map(self, new_grid: List[List[int]]):
        """Updates the map grid (e.g., received from server)."""
        self.grid = new_grid
        self.width = len(self.grid[0]) if self.grid else 0
        self.height = len(self.grid) if self.grid else 0
        print("Map updated.")

    # TODO: Add method to load map from file or server data