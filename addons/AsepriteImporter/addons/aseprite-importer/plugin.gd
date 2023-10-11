@tool
extends EditorPlugin

const Context = preload("./Context.gd")
const SpriteImportPlugin = preload("./importer/sprite_importer.gd")
const Aseprite = preload("./importer/Aseprite.gd")

var context = Context.new()
var aseprite = Aseprite.new(context)
var import_plugins = [
	SpriteImportPlugin.new(context),
]

func _enter_tree():
	context.editor_settings = get_editor_interface().get_editor_settings()
	
	for import_plugin in import_plugins:
		add_import_plugin(import_plugin)

func _exit_tree():
	for import_plugin in import_plugins:
		remove_import_plugin(import_plugin)
