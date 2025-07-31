@tool
extends EditorPlugin


func _enter_tree() -> void:
	# Initialization of the plugin goes here.
	ProjectSettings
	add_custom_type("FrustumShape","Shape3D", preload("res://addons/Observers/FrustumShape.gd"), null)
	add_custom_type("Observer", "Node3D", preload("res://addons/Observers/Observer.gd"), preload("res://addons/Observers/Observer.svg"))
	add_custom_type("ObservationNotifier", "Node3D", preload("res://addons/Observers/ObservationNotifier.gd"), preload("res://addons/Observers/ObservationNotifier.svg"))

func _exit_tree() -> void:
	# Cleanup of the plugin goes here.
	remove_custom_type("Observer")
	remove_custom_type("ObservationNotifier")
	remove_custom_type("FrustumShape")
