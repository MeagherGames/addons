@tool
extends EditorPlugin

var import_plugins = [
	preload("res://addons/aseprite-importer/importers/SceneImporter.gd").new(),
	preload("res://addons/aseprite-importer/importers/AnimatedSprite2DImporter.gd").new(),
	preload("res://addons/aseprite-importer/importers/Sprite2DAnimationPlayerImporter.gd").new(),
	preload("res://addons/aseprite-importer/importers/Texture2DImporter.gd").new(),
]

var tools = [
	preload("res://addons/aseprite-importer/EditorScripts/AnimationTreeFromAnimationPlayer.gd").new(),
]

func _enter_tree():
	for import_plugin in import_plugins:
		add_import_plugin(import_plugin)

	for tool in tools:
		add_tool_menu_item(tool.get_name(), tool.run)

func _exit_tree():
	for import_plugin in import_plugins:
		remove_import_plugin(import_plugin)

	for tool in tools:
		remove_tool_menu_item(tool.get_name())
