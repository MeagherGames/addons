@tool
extends EditorPlugin

func _enter_tree():
	add_custom_type(
        "DirectionalSprite3D",
        "Node3D",
        preload("./DirectionalSprite3D.gd"),
        preload("./DirectionalSprite3D.svg"),
    )

func _exit_tree():
	remove_custom_type("DirectionalSprite3D")
