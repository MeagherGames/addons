@tool
extends EditorPlugin

var import_plugins = [
	preload("./AnimatedSprite2DImporter.gd").new()
]

func _enter_tree():
	for import_plugin in import_plugins:
		add_import_plugin(import_plugin)

func _exit_tree():
	for import_plugin in plugin_instances:
		remove_import_plugin(import_plugins)
