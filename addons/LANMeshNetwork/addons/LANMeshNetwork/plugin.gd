@tool
extends EditorPlugin

func _enable_plugin() -> void:
	# Add autoloads here.
	add_autoload_singleton("LANMeshNetwork", "./LANMeshNetwork.gd")
	pass


func _disable_plugin() -> void:
	# Remove autoloads here.
	remove_autoload_singleton("LANMeshNetwork")
