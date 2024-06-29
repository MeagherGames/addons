@tool
extends EditorImportPlugin

const Aseprite = preload("./Aseprite.gd")

func _get_importer_name(): return "MeagherGames.aseprite.DirectionalSprite3D"

func _get_visible_name(): return "Aseprite DirectionalSprite3D Importer"

func _get_recognized_extensions(): return ["aseprite", "ase"]

func _get_save_extension(): return "tscn"

func _get_resource_type():return "PackedScene"

func _get_preset_count(): return 1

func _get_import_order(): return 0

func _get_priority(): return 1

func _get_preset_name(preset:int): return "Default"

func _get_import_options(path:String, preset:int): return []

func _import(source_file, save_path, options, platform_variants, gen_files):
	var aseprite_file = Aseprite.load_file(source_file, options)
	var path = save_path + "." + _get_save_extension()

	if aseprite_file == null:
		return FAILED
	
	var scene:PackedScene = PackedScene.new()
	# Save an empty scene that will be resaved later
	if ResourceSaver.save(scene, path, ResourceSaver.FLAG_BUNDLE_RESOURCES) != OK:
		return FAILED
	
	var name = aseprite_file.data.meta.image.split(".")[0]

	var directional_sprite_3d:DirectionalSprite3D = DirectionalSprite3D.new()
	directional_sprite_3d.name = name
	directional_sprite_3d.texture = aseprite_file.texture

	# Animations

	# TODO: Implement animations


	scene.pack(directional_sprite_3d)

	# Done
	ResourceSaver.save.call_deferred(scene, path, ResourceSaver.FLAG_BUNDLE_RESOURCES )
	return OK