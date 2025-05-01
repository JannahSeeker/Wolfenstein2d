# renderer.py
import pyray as pr
import math # <-- Added import
import config
from typing import List, Dict, Tuple, Optional

# Import game objects
from player import Player
from remote_player import RemotePlayer, set_observer_state # Import the function too
from sprite import Sprite
from entity import Entity
from map import GameMap
from assets_manager import AssetsManager

# Structure to hold ray hit information
class RayHit:
    def __init__(self, dist: float, wall_id: int, hit_x: float, hit_y: float, side: int, ray_angle: float):
        self.dist = dist          # Distance to wall hit
        self.wall_id = wall_id    # Texture ID of the wall hit
        self.hit_x = hit_x        # Exact world X coordinate of the hit
        self.hit_y = hit_y        # Exact world Y coordinate of the hit
        self.side = side          # 0 for Y-side hit, 1 for X-side hit (for shading/texture coord)
        self.ray_angle = ray_angle # Angle of the ray that caused the hit

class Renderer:
    def __init__(self, assets_manager: AssetsManager):
        self.assets_manager = assets_manager
        self.z_buffer: List[float] = [config.MAX_RENDER_DEPTH] * config.SCREEN_WIDTH # For sprite occlusion

    def _cast_single_ray(self, player: Player, game_map: GameMap, ray_angle: float) -> Optional[RayHit]:
        """Casts a single ray and returns hit information or None."""
        # Normalize angle
        ray_angle %= (2 * math.pi)
        if ray_angle < 0: ray_angle += 2 * math.pi

        map_x = int(player.x)
        map_y = int(player.y)

        # Distances to next X and Y grid lines
        # Avoid division by zero for horizontal/vertical rays
        cos_ray_angle = math.cos(ray_angle)
        sin_ray_angle = math.sin(ray_angle)
        delta_dist_x = abs(1 / cos_ray_angle) if cos_ray_angle != 0 else float('inf')
        delta_dist_y = abs(1 / sin_ray_angle) if sin_ray_angle != 0 else float('inf')


        # Length of ray from current position to next x or y-side
        side_dist_x: float
        side_dist_y: float

        # Step direction (1 or -1)
        step_x: int
        step_y: int

        if cos_ray_angle < 0:
            step_x = -1
            side_dist_x = (player.x - map_x) * delta_dist_x
        else:
            step_x = 1
            side_dist_x = (map_x + 1.0 - player.x) * delta_dist_x

        if sin_ray_angle < 0:
            step_y = -1
            side_dist_y = (player.y - map_y) * delta_dist_y
        else:
            step_y = 1
            side_dist_y = (map_y + 1.0 - player.y) * delta_dist_y

        hit = 0
        side = 0 # 0 for Y-side hit, 1 for X-side hit
        # Use a large number for initial distance comparison, not actual distance yet
        current_dist_x = side_dist_x
        current_dist_y = side_dist_y
        steps = 0
        max_steps = int(config.MAX_RENDER_DEPTH * 2) # Limit steps to prevent infinite loops

        while hit == 0 and steps < max_steps:
            steps += 1
            # Jump to next map square, OR in x-direction, OR in y-direction
            if current_dist_x < current_dist_y:
                # Use current_dist_x for distance calculation before incrementing
                # perp_wall_dist calculation needs the map coords *before* the step that hits
                map_x += step_x
                dist = current_dist_x # Approximate distance travelled
                current_dist_x += delta_dist_x
                side = 1 # Hit an X-side (vertical line)
            else:
                map_y += step_y
                dist = current_dist_y # Approximate distance travelled
                current_dist_y += delta_dist_y
                side = 0 # Hit a Y-side (horizontal line)

            # Check if ray has hit a wall
            if 0 <= map_x < game_map.width and 0 <= map_y < game_map.height:
                 wall_id = game_map.grid[map_y][map_x]
                 if wall_id > 0:
                    hit = wall_id
            else:
                 # Hit edge of map boundaries - treat as a distant wall or stop ray
                 hit = -1 # Special value indicating out of bounds
                 break # Stop casting

            # Check distance limit based on approximate distance travelled
            if dist > config.MAX_RENDER_DEPTH:
                hit = -2 # Indicate hit max distance
                break


        if hit > 0:
             # Calculate perpendicular distance to avoid fisheye effect
             # Use map coordinates of the *wall hit*
             if side == 1: # Hit X-side
                 # (map_x - player.x + (1 - step_x) / 2) is distance along X axis from player to wall center
                 perp_wall_dist = (map_x - player.x + (1 - step_x) / 2) / cos_ray_angle if cos_ray_angle != 0 else float('inf')
             else: # Hit Y-side
                 # (map_y - player.y + (1 - step_y) / 2) is distance along Y axis from player to wall center
                 perp_wall_dist = (map_y - player.y + (1 - step_y) / 2) / sin_ray_angle if sin_ray_angle != 0 else float('inf')

             # Clamp distance if it went slightly beyond due to calculation method
             perp_wall_dist = max(0.01, perp_wall_dist) # Avoid zero distance

             # Calculate exact hit coordinates (needed for texture mapping)
             hit_x = player.x + perp_wall_dist * cos_ray_angle
             hit_y = player.y + perp_wall_dist * sin_ray_angle

             return RayHit(perp_wall_dist, hit, hit_x, hit_y, side, ray_angle)

        return None # No hit within max distance or map bounds


    def _calculate_texture_x(self, hit: RayHit, player: Player) -> float:
         """Calculates the X coordinate on the texture for a wall slice."""
         # Use exact hit coordinates for texture calculation
         wall_x: float # Where exactly the wall was hit (0.0 to 1.0 on the side)
         if hit.side == 1: # Hit an X-side (vertical wall line)
             # Use the Y coordinate of the hit point relative to the map tile floor
             wall_x = hit.hit_y - math.floor(hit.hit_y)
             # Flip texture coordinate if ray is moving left (hitting east face from west)
             if math.cos(hit.ray_angle) < 0:
                 wall_x = 1.0 - wall_x
         else: # Hit a Y-side (horizontal wall line)
             # Use the X coordinate of the hit point relative to the map tile floor
             wall_x = hit.hit_x - math.floor(hit.hit_x)
             # Flip texture coordinate if ray is moving up (hitting south face from north)
             # Screen Y is down. If sin(angle) > 0, ray moves "down" on screen (positive Y in world?)
             # Let's assume world Y increases upwards. sin(angle) > 0 means moving up.
             if math.sin(hit.ray_angle) > 0:
                 wall_x = 1.0 - wall_x

         tex_x = int(wall_x * config.TEXTURE_SIZE)
         # Clamp to texture bounds just in case
         tex_x = max(0, min(tex_x, config.TEXTURE_SIZE - 1))
         return tex_x


    def draw_frame(self,
                   player: Player,
                   game_map: GameMap,
                   remote_players: Dict[str, RemotePlayer],
                   sprites: Dict[str, Sprite],
                   entities: Dict[str, Entity]):
        """Draws the entire game scene for one frame."""
        pr.begin_drawing()
        pr.clear_background(pr.BLACK) # Clear entire screen

        self.draw_floor_ceiling()
        self.draw_walls(player, game_map)
        self.draw_objects(player, remote_players, sprites, entities)
        self.draw_ui(player) # Draw UI on top

        # Draw FPS
        pr.draw_fps(10, 10)

        pr.end_drawing()

    def draw_floor_ceiling(self):
        """Draws the floor and ceiling."""
        # Ceiling
        pr.draw_rectangle(0, 0, config.SCREEN_WIDTH, config.SCREEN_HEIGHT // 2, config.COLOR_CEILING)
        # Floor
        pr.draw_rectangle(0, config.SCREEN_HEIGHT // 2, config.SCREEN_WIDTH, config.SCREEN_HEIGHT // 2, config.COLOR_FLOOR)


    def draw_walls(self, player: Player, game_map: GameMap):
        """Casts rays and draws wall slices."""
        start_angle = player.angle - config.PLAYER_FOV / 2.0
        angle_step = config.PLAYER_FOV / config.NUM_RAYS

        # Reset Z-Buffer for this frame
        self.z_buffer = [config.MAX_RENDER_DEPTH] * config.SCREEN_WIDTH

        for i in range(config.NUM_RAYS):
            ray_angle = start_angle + i * angle_step
            hit = self._cast_single_ray(player, game_map, ray_angle)

            screen_x = i * config.RENDER_SCALE_FACTOR # Scale wall slice width

            if hit:
                # Store distance in Z-buffer for sprite occlusion
                # Clamp distance to prevent issues
                z_dist = max(0.01, hit.dist)
                for k in range(config.RENDER_SCALE_FACTOR):
                    buffer_idx = screen_x + k
                    if 0 <= buffer_idx < config.SCREEN_WIDTH:
                        self.z_buffer[buffer_idx] = z_dist

                # Calculate wall slice height - avoid division by zero
                line_height = int(config.SCREEN_HEIGHT / z_dist) if z_dist > 0.01 else config.SCREEN_HEIGHT * 100

                # Calculate drawing start and end points on screen
                draw_start = -line_height // 2 + config.SCREEN_HEIGHT // 2
                draw_end = line_height // 2 + config.SCREEN_HEIGHT // 2

                # Get texture
                wall_texture = self.assets_manager.get_wall_texture(hit.wall_id)

                # Calculate texture X coordinate
                tex_x = self._calculate_texture_x(hit, player)

                # Define source rectangle on the texture
                tex_rect_src = pr.Rectangle(tex_x, 0, 1, float(wall_texture.height)) # Use texture height

                # Define destination rectangle on the screen
                tex_rect_dest = pr.Rectangle(float(screen_x), float(draw_start), float(config.RENDER_SCALE_FACTOR), float(line_height))

                # Apply simple shading based on wall side
                tint = pr.WHITE
                if hit.side == 1: # X-side hit, make slightly darker
                     tint = pr.Color(200, 200, 200, 255)

                # Draw the texture slice
                pr.draw_texture_pro(wall_texture, tex_rect_src, tex_rect_dest, pr.Vector2(0, 0), 0.0, tint)

            # else: # No need to explicitly clear z_buffer if initialized each frame
            #      pass


    def draw_objects(self,
                      player: Player,
                      remote_players: Dict[str, RemotePlayer],
                      sprites: Dict[str, Sprite],
                      entities: Dict[str, Entity]):
        """Draws all sprites and entities, sorted by distance."""

        set_observer_state(player.get_pos_tuple(), player.angle) # For remote player texture direction

        # --- Combine all drawable objects into one list ---
        all_objects = []
        # Add remote players
        for rp in remote_players.values():
            if not rp.is_dead: # Simple check
                tex_index = rp.get_texture_index(player.angle)
                texture = self.assets_manager.get_sprite_texture(rp.sprite_name, tex_index)
                all_objects.append({
                    "x": rp.x, "y": rp.y, "texture": texture, "scale": config.SPRITE_SCALE,
                    "obj_ref": rp })
        # Add generic sprites
        for sp in sprites.values():
             if sp.should_draw():
                texture = self.assets_manager.get_sprite_texture(sp.texture_name, sp.texture_index)
                all_objects.append({
                    "x": sp.x, "y": sp.y, "texture": texture, "scale": sp.scale,
                    "obj_ref": sp })
        # Add entities
        for ent in entities.values():
            if ent.should_draw():
                texture = self.assets_manager.get_sprite_texture(ent.texture_name, ent.texture_index)
                all_objects.append({
                    "x": ent.x, "y": ent.y, "texture": texture, "scale": ent.scale,
                    "obj_ref": ent })

        # --- Calculate distance squared and sort ---
        for obj in all_objects:
            dx = obj["x"] - player.x
            dy = obj["y"] - player.y
            obj["dist_sq"] = dx*dx + dy*dy

        all_objects.sort(key=lambda s: s["dist_sq"], reverse=True) # Furthest first

        # --- Get Player Vectors ---
        player_dir_x, player_dir_y = player.get_dir_vector()
        player_plane_x, player_plane_y = player.get_plane_vector() # Using updated get_plane_vector

        # --- Draw sorted objects ---
        for obj in all_objects:
            # --- Step 1: Translate to Player-Relative Coordinates ---
            sprite_x = obj["x"] - player.x
            sprite_y = obj["y"] - player.y

            # --- Step 2: Transform using Inverse Camera Matrix ---
            det = (player_plane_x * player_dir_y - player_dir_x * player_plane_y)
            if abs(det) < 1e-9: # Avoid division by zero
                continue

            inv_det = 1.0 / det
            transform_x = inv_det * (player_dir_y * sprite_x - player_dir_x * sprite_y)
            transform_y = inv_det * (-player_plane_y * sprite_x + player_plane_x * sprite_y)


            # --- DEBUGGING PRINTS ---
            is_test_sprite = False
            obj_ref = obj.get("obj_ref")
            # Check if obj_ref exists and has an 'id' attribute before accessing it
            if obj_ref and hasattr(obj_ref, 'id') and obj_ref.id == "sprite_guard_npc":
                is_test_sprite = True
                print(f"--- Debug Sprite (sprite_guard_npc) ---")
                print(f"  World Pos: ({obj['x']:.2f}, {obj['y']:.2f})")
                print(f"  Player Pos: ({player.x:.2f}, {player.y:.2f}, Angle: {math.degrees(player.angle):.1f} deg)")
                print(f"  Relative Pos (sprite_x, sprite_y): ({sprite_x:.2f}, {sprite_y:.2f})")
                print(f"  Player Dir (x,y): ({player_dir_x:.2f}, {player_dir_y:.2f})")
                print(f"  Player Plane (x,y): ({player_plane_x:.2f}, {player_plane_y:.2f})")
                print(f"  Determinant (det): {det:.4f}") # Print determinant itself
                print(f"  Inverse Determinant (inv_det): {inv_det:.4f}")
                print(f"  Camera Space (transform_x, transform_y): ({transform_x:.4f}, {transform_y:.4f})")
            # --- END DEBUGGING PRINTS ---


            # --- Step 3: Check if Sprite is Behind Camera ---
            if transform_y <= 0.1:
                 if is_test_sprite:
                     print(f"  CULLED: transform_y ({transform_y:.4f}) <= 0.1")
                     print(f"--------------------------------------")
                 continue

            # --- Step 4: Calculate Screen Coordinates and Dimensions ---
            sprite_screen_x = int((config.SCREEN_WIDTH / 2) * (1 + transform_x / transform_y))
            sprite_height = abs(int(config.SCREEN_HEIGHT / transform_y * obj["scale"]))
            aspect_ratio = 1.0
            current_texture = obj.get("texture") # Get texture safely
            if current_texture and current_texture.height != 0:
                 aspect_ratio = float(current_texture.width) / float(current_texture.height)
            sprite_width = abs(int(sprite_height * aspect_ratio))

            # --- Step 5: Calculate Drawing Bounds on Screen (Clamped) ---
            vertical_offset = sprite_height // 5
            draw_start_y = -sprite_height // 2 + config.SCREEN_HEIGHT // 2 + vertical_offset
            draw_end_y = sprite_height // 2 + config.SCREEN_HEIGHT // 2 + vertical_offset
            draw_start_y_clamped = max(0, draw_start_y)
            draw_end_y_clamped = min(config.SCREEN_HEIGHT, draw_end_y)

            draw_start_x = -sprite_width // 2 + sprite_screen_x
            draw_end_x = sprite_width // 2 + sprite_screen_x
            draw_start_x_clamped = max(0, draw_start_x)
            draw_end_x_clamped = min(config.SCREEN_WIDTH, draw_end_x)

            # --- Step 6: Draw Vertical Stripes with Z-Buffer Check ---
            tex_rect_src_h = float(current_texture.height) if current_texture else 0.0
            tex_rect_src_w = float(current_texture.width) if current_texture else 0.0

            # Check for invalid texture dimensions or zero calculated sprite width
            if tex_rect_src_h <= 0 or tex_rect_src_w <= 0 or sprite_width <= 0: continue

            # Calculate the actual visible height on screen AFTER clamping
            clamped_dest_height = float(draw_end_y_clamped - draw_start_y_clamped)

            # Only proceed if there's actually something to draw vertically
            if clamped_dest_height > 0 and sprite_height > 0: # Also check original height to prevent division by zero

                for stripe in range(draw_start_x_clamped, draw_end_x_clamped):
                    # Check Z-buffer (only draw if in front of wall/object at this stripe)
                    if 0 <= stripe < config.SCREEN_WIDTH and transform_y < self.z_buffer[stripe]:

                        # --- Calculate Texture X Coordinate (Horizontal) ---
                        # Map screen stripe coordinate (relative to sprite's screen start) -> texture X
                        tex_el_x = stripe - draw_start_x # How many pixels into the sprite width are we?
                        tex_x = int(tex_el_x * tex_rect_src_w / sprite_width) # Map to texture width

                        # Ensure tex_x is valid (can happen with float inaccuracies)
                        if 0 <= tex_x < tex_rect_src_w:

                            # --- Adjust Source Rect Y and Height for Vertical Clamping ---
                            # Calculate how much of the sprite was clipped from the top (in texture space)
                            clip_top_pixels_screen = draw_start_y_clamped - draw_start_y
                            # Convert screen pixel clipping to texture pixel clipping
                            src_y_offset = (clip_top_pixels_screen / float(sprite_height)) * tex_rect_src_h

                            # Calculate how much of the sprite height is visible (in texture space)
                            visible_height_ratio = clamped_dest_height / float(sprite_height)
                            src_h = visible_height_ratio * tex_rect_src_h

                            # Clamp source coordinates to texture bounds
                            src_y = max(0.0, min(src_y_offset, tex_rect_src_h))
                            src_h = max(0.0, min(src_h, tex_rect_src_h - src_y))
                            # --- End Source Rect Adjustment ---

                            # Check if calculated source height is valid before drawing
                            if src_h > 0:
                                # Source rect for this single *visible portion* of the vertical texture stripe
                                stripe_src_rect = pr.Rectangle(float(tex_x), src_y, 1.0, src_h)

                                # Destination rect for this single vertical stripe *on screen*
                                # Use clamped Y start and clamped height
                                stripe_dest_rect = pr.Rectangle(float(stripe), float(draw_start_y_clamped), 1.0, clamped_dest_height)

                                # Draw the texture segment
                                pr.draw_texture_pro(current_texture, stripe_src_rect, stripe_dest_rect, pr.Vector2(0,0), 0.0, pr.WHITE)

    def draw_ui(self, player: Player):
         """Draws User Interface elements like health, ammo, etc."""
         # Simple health bar example
         health_percentage = max(0.0, player.health / config.PLAYER_HEALTH_START) # Ensure >= 0
         health_bar_width = 200
         health_bar_height = 20
         health_current_width = int(health_bar_width * health_percentage)

         pr.draw_rectangle(10, config.SCREEN_HEIGHT - 30, health_bar_width, health_bar_height, pr.GRAY)
         pr.draw_rectangle(10, config.SCREEN_HEIGHT - 30, health_current_width, health_bar_height, pr.RED)
         pr.draw_text(f"HP: {player.health}", 15, config.SCREEN_HEIGHT - 28, 18, pr.WHITE)

         # Draw "DEAD" message if applicable
         if player.is_dead:
             msg = "YOU ARE DEAD"
             text_width = pr.measure_text(msg, 60)
             pr.draw_text(msg, (config.SCREEN_WIDTH - text_width)//2, config.SCREEN_HEIGHT//2 - 30, 60, pr.RED)
        
         mana_percentage = max(0.0, player.mana / config.PLAYER_MANA_START) # Ensure >= 0
         mana_bar_width = 200
         mana_bar_height = 20
         mana_current_width = int(mana_bar_width * mana_percentage)

         pr.draw_rectangle(config.SCREEN_WIDTH-10-mana_bar_width, config.SCREEN_HEIGHT - 30, mana_bar_width, mana_bar_height, pr.GRAY)
         pr.draw_rectangle(config.SCREEN_WIDTH-10-mana_bar_width, config.SCREEN_HEIGHT - 30, mana_current_width, mana_bar_height, pr.BLUE)
         pr.draw_text(f"Mana: {player.mana}", config.SCREEN_WIDTH-10, config.SCREEN_HEIGHT - 28, 18, pr.WHITE)