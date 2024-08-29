@tool
extends EditorPlugin

var import_plugins = [
	preload("res://addons/krita-importer/importers/Texture2DImporter.gd").new(),
]

func _enter_tree():
	ProjectSettings.set("editor/import/use_multiple_threads", false) # There is a bug with the importers and multiple threads
	for import_plugin in import_plugins:
		add_import_plugin(import_plugin)

func _exit_tree():
	for import_plugin in import_plugins:
		remove_import_plugin(import_plugin)