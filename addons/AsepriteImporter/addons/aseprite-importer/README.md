# Aseprite Importer - User Data Options

This guide covers the user data options you can use in your Aseprite files to control how they're imported into Godot.

## Animation Tag User Data

Add these keywords to your animation tag's "User Data" field (comma-separated):

- `autoplay` - Makes this animation play automatically when the scene loads
- `no_loop` - Forces the animation to play only once, ignoring the tag's loop mode

## Layer User Data

Add these keywords to your layer's "User Data" field (comma-separated):

- `no_atlas` - Excludes this layer from the texture atlas and imports it as a Node2D

## Special Layer Names

- Layers with `-noimp` in their name will be automatically excluded from import

## Notes

- User data should be comma-separated if using multiple options
- Keywords are case-sensitive

