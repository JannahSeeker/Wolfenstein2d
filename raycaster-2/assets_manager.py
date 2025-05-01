# assets_manager.py
import pyray as pr
import os
import config
from typing import Dict, List, Optional

class AssetsManager:
    def __init__(self):
        self.wall_textures: Dict[int, pr.Texture2D] = {}
        self.sprite_textures: Dict[str, List[pr.Texture2D]] = {} # e.g., {"WinterGuard": [tex1, tex2...]}
        self.error_texture: Optional[pr.Texture2D] = None
        self._create_error_texture()

    def _create_error_texture(self):
        """Creates a fallback texture for missing assets."""
        img = pr.gen_image_checked(config.TEXTURE_SIZE, config.TEXTURE_SIZE, 16, 16, pr.PINK, pr.BLACK)
        self.error_texture = pr.load_texture_from_image(img)
        pr.unload_image(img)
        print("Generated error texture.")

    def load_assets(self, assets_dir: str = "assets"):
        """Loads all wall and sprite textures."""
        print("Loading assets...")
        self._load_wall_textures(os.path.join(assets_dir, "textures"))
        self._load_sprites(os.path.join(assets_dir, "sprites"))
        print("Asset loading complete.")

    def _load_wall_textures(self, textures_path: str):
        print(f" Looking for wall textures in: {textures_path}")
        if not os.path.isdir(textures_path):
            print(f" Warning: Wall texture directory not found: {textures_path}")
            return

        for filename in os.listdir(textures_path):
            if filename.startswith("wall_") and filename.endswith(".png"):
                try:
                    wall_id_str = filename.split('_')[1].split('.')[0]
                    wall_id = int(wall_id_str)
                    filepath = os.path.join(textures_path, filename)
                    texture = pr.load_texture(filepath)
                    if texture.id == 0: # Check if loading failed
                         print(f" Warning: Failed to load texture: {filepath}. Using error texture.")
                         self.wall_textures[wall_id] = self.error_texture
                    else:
                         self.wall_textures[wall_id] = texture
                         pr.gen_texture_mipmaps(self.wall_textures[wall_id])
                         pr.set_texture_filter(self.wall_textures[wall_id], pr.TextureFilter.TEXTURE_FILTER_TRILINEAR)
                         print(f"  Loaded wall texture ID {wall_id}: {filename}")
                except (IndexError, ValueError) as e:
                    print(f" Warning: Could not parse wall ID from filename: {filename} ({e})")
                except Exception as e:
                     print(f" Error loading texture {filename}: {e}")
                     # Assign error texture if ID was parsed but loading failed later
                     if 'wall_id' in locals():
                         self.wall_textures[wall_id] = self.error_texture

        if not self.wall_textures:
            print(" Warning: No wall textures were loaded.")

    def _load_sprites(self, sprites_path: str):
        print(f" Looking for sprites in: {sprites_path}")
        if not os.path.isdir(sprites_path):
            print(f" Warning: Sprites directory not found: {sprites_path}")
            return

        sprite_files = {} # Group files by sprite name (e.g., "WinterGuard")
        for filename in os.listdir(sprites_path):
            if filename.endswith(".png"):
                parts = filename.split('_')
                if len(parts) >= 2:
                    sprite_name = parts[0]
                    try:
                        sprite_index = int(parts[-1].split('.')[0]) # Get the number at the end
                        if sprite_name not in sprite_files:
                            sprite_files[sprite_name] = []
                        sprite_files[sprite_name].append((sprite_index, os.path.join(sprites_path, filename)))
                    except ValueError:
                        print(f" Warning: Could not parse sprite index from filename: {filename}")
                else:
                     print(f" Warning: Skipping sprite file with unexpected name format: {filename}")


        for sprite_name, files in sprite_files.items():
            # Sort files by index to ensure correct order
            files.sort(key=lambda item: item[0])

            self.sprite_textures[sprite_name] = []
            max_index = files[-1][0] if files else 0
            # Ensure list is large enough, fill potentially missing ones with error texture
            self.sprite_textures[sprite_name] = [self.error_texture] * (max_index + 1)

            print(f"  Loading sprite '{sprite_name}'...")
            for index, filepath in files:
                texture = pr.load_texture(filepath)
                if texture.id == 0:
                    print(f"   Warning: Failed to load sprite index {index}: {filepath}. Using error texture.")
                    # Already pre-filled with error texture
                else:
                    self.sprite_textures[sprite_name][index] = texture
                    pr.gen_texture_mipmaps(self.sprite_textures[sprite_name][index])
                    pr.set_texture_filter(self.sprite_textures[sprite_name][index], pr.TextureFilter.TEXTURE_FILTER_TRILINEAR)
                    print(f"   Loaded sprite index {index}: {os.path.basename(filepath)}")

        if not self.sprite_textures:
             print(" Warning: No sprites were loaded.")


    def get_wall_texture(self, wall_id: int) -> pr.Texture2D:
        """Gets a wall texture by ID, returns error texture if not found."""
        return self.wall_textures.get(wall_id, self.error_texture)

    def get_sprite_texture(self, sprite_name: str, index: int) -> pr.Texture2D:
        """Gets a specific sprite texture, returns error texture if not found."""
        if sprite_name in self.sprite_textures:
            textures = self.sprite_textures[sprite_name]
            # Check index bounds explicitly, using 0-based index
            if 0 <= index < len(textures):
                return textures[index]
            else:
                 print(f"Warning: Sprite index {index} out of bounds for '{sprite_name}' (max: {len(textures)-1}).")
                 return self.error_texture # Out of bounds
        print(f"Warning: Sprite name '{sprite_name}' not found.")
        return self.error_texture # Sprite name not found

    def unload_assets(self):
        """Unloads all loaded textures."""
        print("Unloading assets...")
        for texture in self.wall_textures.values():
            if texture and texture.id != self.error_texture.id: # Avoid unloading the error texture multiple times
                pr.unload_texture(texture)
        for sprite_name in self.sprite_textures:
             for texture in self.sprite_textures[sprite_name]:
                 if texture and texture.id != self.error_texture.id:
                     pr.unload_texture(texture)

        if self.error_texture:
             pr.unload_texture(self.error_texture) # Unload the error texture once

        self.wall_textures.clear()
        self.sprite_textures.clear()
        print("Assets unloaded.")