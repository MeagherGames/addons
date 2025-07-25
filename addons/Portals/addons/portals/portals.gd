@tool
extends EditorPlugin


func _enter_tree() -> void:
	add_custom_type("Portal3D", "MeshInstance3D", preload("res://addons/portals/scripts/portal_3d.gd"), preload("res://addons/portals/assets/portal_3d.svg"))


func _exit_tree() -> void:
	# Clean up custom type when exiting the editor
	remove_custom_type("Portal3D")
