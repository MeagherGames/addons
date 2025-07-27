@tool
extends EditorPlugin

const AUTOLOAD_NAME = "MultiplayerSceneManager"
const AUTOLOAD_PATH = "res://addons/multiplayer_scene_manager/scene_manager.gd"

func _enter_tree() -> void:
	# Initialization of the plugin goes here.
	add_autoload_singleton(AUTOLOAD_NAME, AUTOLOAD_PATH)


func _exit_tree() -> void:
	# Clean-up of the plugin goes here.
	remove_autoload_singleton(AUTOLOAD_NAME)
