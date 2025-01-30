@tool
extends EditorImportPlugin

const Aseprite = preload("res://addons/aseprite-importer/Aseprite/Aseprite.gd")

func _get_importer_name(): return "MeagherGames.aseprite.SpriteFrames"

func _get_visible_name(): return "Aseprite SpriteFrames Importer"

func _get_recognized_extensions(): return ["aseprite", "ase"]

func _get_save_extension(): return "tres"

func _get_resource_type():return "SpriteFrames"

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
		printerr("SpriteFrames does not support layers")
		return FAILED

	# Animations
	var sprite_frames:SpriteFrames = SpriteFrames.new()
	sprite_frames.remove_animation("default")
	
	# Only support one layer for now
	var layer = aseprite_file.layers[0]
	for ase_animation in aseprite_file.animations:
		sprite_frames.add_animation(ase_animation.name)
		sprite_frames.set_animation_loop(ase_animation.name, true)
		sprite_frames.set_animation_speed(ase_animation.name, 1.0)

		var frames = layer.get_animation_data(ase_animation).frames

		if ase_animation.loop_mode == Animation.LOOP_PINGPONG:
			var reversed_frames = frames.slice(1, frames.size() - 1)
			reversed_frames.reverse()
			frames = frames + reversed_frames
		if ase_animation.reverse:
			frames.reverse()

		for frame_data in frames:
			var texture = AtlasTexture.new()
			texture.atlas = aseprite_file.texture
			texture.region = frame_data.region
			sprite_frames.add_frame(ase_animation.name, texture, frame_data.duration)
	
	return ResourceSaver.save(sprite_frames, path)