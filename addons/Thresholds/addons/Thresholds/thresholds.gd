@tool
extends EditorPlugin


func _enter_tree() -> void:
	# Initialization of the plugin goes here.
	add_custom_type("Threshold", "Node3D", preload("res://addons/Thresholds/Threshold.gd"),
		preload("res://addons/Thresholds/Threshold.svg"))
	add_custom_type("PsudoCamera", "Node3D", preload("res://addons/Thresholds/PsudoCamera.gd"), preload("res://addons/Thresholds/PsudoCamera.svg"))

func _exit_tree() -> void:
	# Cleanup of the plugin goes here.
	remove_custom_type("Threshold")
	remove_custom_type("PsudoCamera")
