@tool
extends EditorPlugin


func _enable_plugin() -> void:
	add_autoload_singleton("MeshMultiplayer", "res://addons/mesh-multiplayer/MeshMultiplayer.gd")


func _disable_plugin() -> void:
	remove_autoload_singleton("MeshMultiplayer")

