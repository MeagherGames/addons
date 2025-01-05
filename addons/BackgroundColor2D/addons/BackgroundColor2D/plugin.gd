@tool
extends EditorPlugin

const BackgroundColor2DIconPath := "res://addons/BackgroundColor2D/BackgroundColor2D.png"
const BackgroundColor2DScriptPath := "res://addons/BackgroundColor2D/BackgroundColor2D.gd"

func _enter_tree() -> void:
	add_custom_type(
		"BackgroundColor2D",
		"Node2D",
		preload(BackgroundColor2DScriptPath),
		load(BackgroundColor2DIconPath)
	)


func _exit_tree() -> void:
	# Clean-up of the plugin goes here.
	remove_custom_type("BackgroundColor2D")
	pass
