@tool
extends EditorPlugin

var import_plugins = [
	preload("res://addons/aseprite-importer/importers/AnimatedSprite2DImporter.gd").new(),
	preload("res://addons/aseprite-importer/importers/Sprite2DAnimationPlayerImporter.gd").new(),
	preload("res://addons/aseprite-importer/importers/SpriteFramesImporter.gd").new(),
	preload("res://addons/aseprite-importer/importers/Texture2DImporter.gd").new(),
	preload("res://addons/aseprite-importer/importers/DirectionalSprite3DImporter.gd").new(),
]

func _enter_tree():
	ProjectSettings.set("editor/import/use_multiple_threads", false) # There is a bug with the importers and multiple threads
	for import_plugin in import_plugins:
		add_import_plugin(import_plugin)

func _exit_tree():
	for import_plugin in import_plugins:
		remove_import_plugin(import_plugin)
