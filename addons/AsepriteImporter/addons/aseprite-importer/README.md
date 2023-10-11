# Godot Aseprite Importer
Godot version 4.x

This importer lets you just put aseprite/ase files in your project and they get imported as Sprite2D or Sprite3D nodes with an animation player.

## User Data
This importer also handles user_data, cel user data gets added to the animation you can get the value by doing `sprite.get_meta("aseprite_user_data", [])`

if a frame tag has user data with `autoplay` it will be set to automatically play on load in the editor. if you have multiple tags with autoplay in the user data only the last one will be set to play when the scene loads.