# config.py
import math
import pyray as pr

# Screen Dimensions
SCREEN_WIDTH = 1280
SCREEN_HEIGHT = 720
TARGET_FPS = 60

# Player Settings
PLAYER_START_X = 3.5
PLAYER_START_Y = 3.5
PLAYER_START_ANGLE = 0.0 # Radians
PLAYER_MOVE_SPEED = 2.5  # Units per second
PLAYER_RUN_MULTIPLIER = 1.8
PLAYER_ROTATION_SPEED = 2.0 # Radians per second
PLAYER_FOV = math.radians(60) # Field of View in radians
PLAYER_HEALTH_START = 100

# Rendering Settings
NUM_RAYS = SCREEN_WIDTH // 2 # Number of rays to cast (adjust for performance/quality)
MAX_RENDER_DEPTH = 20.0    # Maximum distance to render walls/sprites
TEXTURE_SIZE = 128         # Assuming square textures (width & height)
RENDER_SCALE_FACTOR = 2   # For drawing wall slices wider than 1 pixel

# Map Settings
MAP_TILE_SIZE = 1.0 # Size of one map tile in world units

# Network Settings
# Replace with your actual server IP and Port
SERVER_IP = "153.33.125.221" # Loopback for local testing
SERVER_PORT = 5555
NETWORK_UPDATE_RATE = 1 / 20 # Send updates to server 20 times per second
SOCKET_TIMEOUT = 0.01 # Short timeout for non-blocking receive

# Sprite/Asset Settings
SPRITE_SCALE = 0.7 # General scaling for sprites in the world

# Colors
COLOR_FLOOR = pr.Color(50, 50, 50, 255)    # Dark Gray
COLOR_CEILING = pr.Color(100, 100, 100, 255) # Lighter Gray
COLOR_DEBUG_RAY = pr.Color(255, 0, 0, 100)   # Red for debug
COLOR_DEBUG_MAP = pr.Color(0, 0, 255, 150)   # Blue for debug map

# Sprite ID mapping for WinterGuard (example)
# This helps translate server state to texture index
SPRITE_WINTERGUARD_IDLE_START = 1
SPRITE_WINTERGUARD_WALK_START = 9
SPRITE_WINTERGUARD_RUN_START = 17
SPRITE_DIRECTIONS = 8 # 8 directions for each state

# Game States
STATE_MENU = 0
STATE_PLAYING = 1
STATE_GAME_OVER = 2
STATE_CONNECTING = 3