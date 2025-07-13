@tool
extends EditorImportPlugin

const Aseprite = preload("res://addons/aseprite-importer/Aseprite/Aseprite.gd")

func _get_importer_name(): return "MeagherGames.aseprite.Texture2D"

func _get_visible_name(): return "Aseprite Texture2D Importer"

func _get_recognized_extensions(): return ["aseprite", "ase"]

func _get_save_extension(): return "res"

func _get_resource_type(): return "Texture2D"

func _get_preset_count(): return 1

func _get_import_order(): return 0

func _get_priority(): return 1

func _get_preset_name(_preset: int): return "Default"

func _get_import_options(_path: String, _preset: int) -> Array[Dictionary]:
	return [
		{
			"name": "grid_pack",
			"default_value": true,
		},
	]

func _get_option_visibility(path: String, option_name: StringName, options: Dictionary) -> bool:
	return true

func _get_option_visibility(path:String, option_name:StringName, options:Dictionary): return false

func _import(source_file, save_path, options, _platform_variants, _gen_files):
	if options.get("grid_pack", true):
		options.pack_mode = "grid"
	var aseprite_file = Aseprite.load_file(source_file, options)
	var path = save_path + "." + _get_save_extension()

	if aseprite_file.is_empty():
		return FAILED
	
	var atlas_texture = ImageTexture.create_from_image(Image.load_from_file(aseprite_file.meta.atlas_path))
	return ResourceSaver.save(atlas_texture, path)