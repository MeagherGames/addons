@tool
extends EditorImportPlugin

const Aseprite = preload("res://addons/aseprite-importer/Aseprite/Aseprite.gd")

func _get_importer_name(): return "MeagherGames.aseprite.Sprite2DAnimationPlayer"

func _get_visible_name(): return "Aseprite Sprite2DAnimationPlayer Importer"

func _get_recognized_extensions(): return ["aseprite", "ase"]

func _get_save_extension(): return "tscn"

func _get_resource_type():return "PackedScene"

func _get_preset_count(): return 1

func _get_import_order(): return 0

func _get_priority(): return 1

func _get_preset_name(_preset:int): return "Default"

func _get_import_options(_path:String, _preset:int): return []

func _import(source_file, save_path, options, _platform_variants, _gen_files):
	var aseprite_file = Aseprite.load_file(source_file, options)
	var path = save_path + "." + _get_save_extension()

	if aseprite_file == null:
		return FAILED

	if aseprite_file.has_layers():
		printerr("Sprite2DAnimationPlayer does not support layers")
		return FAILED
	
	var sprite_2d:Sprite2D = Sprite2D.new()
	sprite_2d.name = aseprite_file.name
	
	sprite_2d.texture = aseprite_file.texture
	sprite_2d.hframes = aseprite_file.hframes
	sprite_2d.vframes = aseprite_file.vframes
	
	var animation_player:AnimationPlayer = AnimationPlayer.new()
	var animation_library:AnimationLibrary = AnimationLibrary.new()
	
	var layer = aseprite_file.layers[0]
	var autoplay_animation = ""
	for ase_animation in aseprite_file.animations:

		var animation:Animation = Animation.new()
		animation.loop_mode = ase_animation.loop_mode
		var data = layer.get_animation_data(ase_animation)
		var frame_track = animation.add_track(Animation.TYPE_VALUE)
		animation.value_track_set_update_mode(frame_track, Animation.UPDATE_DISCRETE)
		animation.track_set_interpolation_loop_wrap(frame_track, false)
		animation.track_set_path(frame_track, ".:frame")
		

		for i in data.frames.size():
			animation.track_insert_key(
				frame_track,
				data.timing[i],
				data.frames[i].index
			)

		animation.length = data.length
		animation_library.add_animation(ase_animation.name, animation)
		if ase_animation.autoplay:
			autoplay_animation = ase_animation.name

	animation_player.add_animation_library("", animation_library)
	
	sprite_2d.add_child(animation_player, true)
	animation_player.owner = sprite_2d
	animation_player.current_animation = autoplay_animation
	animation_player.autoplay = autoplay_animation
	
	var scene:PackedScene = PackedScene.new()
	var result = scene.pack(sprite_2d)
	return ResourceSaver.save(scene, path)
