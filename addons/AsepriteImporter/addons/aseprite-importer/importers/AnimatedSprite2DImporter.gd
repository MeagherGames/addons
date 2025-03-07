@tool
extends EditorImportPlugin

const Aseprite = preload("res://addons/aseprite-importer/Aseprite/Aseprite.gd")

func _get_importer_name(): return "MeagherGames.aseprite.AnimatedSprite2D"

func _get_visible_name(): return "Aseprite AnimatedSprite2D Importer"

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
		printerr("AnimatedSprite2D does not support layers")
		return FAILED

	var animation_sprite_2d:AnimatedSprite2D = AnimatedSprite2D.new()
	animation_sprite_2d.name = aseprite_file.name

	# Animations
	var sprite_frames:SpriteFrames = SpriteFrames.new()
	sprite_frames.remove_animation("default")
	
	# Only support one layer for now
	var layer = aseprite_file.layers[0]
	for ase_animation in aseprite_file.animations:
		sprite_frames.add_animation(ase_animation.name)
		sprite_frames.set_animation_loop(ase_animation.name, ase_animation.loop_mode != Animation.LOOP_NONE)
		sprite_frames.set_animation_speed(ase_animation.name, 1.0)

		if ase_animation.autoplay:
			animation_sprite_2d.autoplay = StringName(ase_animation.name)

		var data = layer.get_animation_data(ase_animation)

		for frame_data in data.frames:
			var texture = AtlasTexture.new()
			texture.atlas = aseprite_file.texture
			texture.region = frame_data.region
			sprite_frames.add_frame(ase_animation.name, texture, frame_data.duration)
	
	animation_sprite_2d.frames = sprite_frames

	var scene:PackedScene = PackedScene.new()
	scene.pack(animation_sprite_2d)
	return ResourceSaver.save(scene, path)