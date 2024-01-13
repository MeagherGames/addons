@tool
extends EditorPlugin

var import_plugins = [
	preload("./importer/AnimatedSprite2DImporter.gd").new(),
	preload("./importer/Texture2DImporter.gd").new()
]

func _enter_tree():
	for import_plugin in import_plugins:
		add_import_plugin(import_plugin)

func _exit_tree():
	for import_plugin in import_plugins:
		remove_import_plugin(import_plugin)
