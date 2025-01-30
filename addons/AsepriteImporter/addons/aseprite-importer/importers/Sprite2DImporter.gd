@tool
extends EditorImportPlugin

const Aseprite = preload("res://addons/aseprite-importer/Aseprite/Aseprite.gd")

func _get_importer_name(): return "MeagherGames.aseprite.Sprite2D"

func _get_visible_name(): return "Aseprite Sprite2D Importer"

func _get_recognized_extensions(): return ["aseprite", "ase"]

func _get_save_extension(): return "tscn"

func _get_resource_type():return "PackedScene"

func _get_preset_count(): return 1

func _get_import_order(): return 0

func _get_priority(): return 1

func _get_preset_name(_preset:int): return "Default"

func _get_import_options(_path:String, _preset:int): return []

func _get_option_visibility(path:String, option_name:StringName, options:Dictionary): return false

func _import(source_file, save_path, options, _platform_variants, _gen_files):
	var aseprite_file = Aseprite.load_file(source_file, options)
	var path = save_path + "." + _get_save_extension()

	if aseprite_file == null:
		return FAILED

	if aseprite_file.has_layers():
		printerr("Sprite2D does not support layers")
		return FAILED

	var sprite_2d:Sprite2D = Sprite2D.new()
	sprite_2d.name = aseprite_file.name

	sprite_2d.texture = aseprite_file.texture
	sprite_2d.hframes = aseprite_file.hframes
	sprite_2d.vframes = aseprite_file.vframes

	var scene:PackedScene = PackedScene.new()
	scene.pack(sprite_2d)
	return ResourceSaver.save(scene, path)