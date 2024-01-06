@tool
extends EditorImportPlugin

const Aseprite = preload("./Aseprite.gd")

func _get_importer_name(): return "MeagherGames.aseprite.AnimatedSprite2D"

func _get_visible_name(): return "Aseprite AnimatedSprite2D Importer"

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

	if aseprite_file == null:
		return FAILED
	
	var scene:PackedScene = PackedScene.new()
	var path = save_path + "." + _get_save_extension()
	# Save an empty scene that will be resaved later
	if ResourceSaver.save(scene, path, ResourceSaver.FLAG_BUNDLE_RESOURCES) != OK:
		return FAILED
	
	var name = aseprite_file.data.meta.image.split(".")[0]

	var animation_sprite_2d:AnimatedSprite2D = AnimatedSprite2D.new()
	animation_sprite_2d.name = name

	# Animations
	var sprite_frames:SpriteFrames = SpriteFrames.new()
	sprite_frames.remove_animation("default")
	
	for animation_data in aseprite_file.animations:
		sprite_frames.add_animation(animation_data.name)
		sprite_frames.set_animation_loop(animation_data.name, true)
		sprite_frames.set_animation_speed(animation_data.name, 1.0)

		if animation_data.autoplay:
			animation_sprite_2d.autoplay = animation_data.name

		var frames = []
		for frame in range(animation_data.from, animation_data.to + 1):
			var frame_data = aseprite_file.get_frame_data(frame)
			frames.append(frame_data)
		
		if animation_data.direction == "reverse":
			frames.reverse()
		elif animation_data.direction == "pingpong":
			var reversed_frames = frames.slice(1, frames.size() - 1)
			reversed_frames.reverse()
			frames = frames + reversed_frames
		elif animation_data.direction == "pingpong_reverse":
			var reversed_frames = frames.slice(1, frames.size() - 1)
			reversed_frames.reverse()
			frames = frames + reversed_frames
			frames.reverse()

		for frame_data in frames:
			sprite_frames.add_frame(animation_data.name, frame_data.texture, frame_data.duration)
	
	animation_sprite_2d.frames = sprite_frames


	scene.pack(animation_sprite_2d)

	# Done
	ResourceSaver.save.call_deferred(scene, path, ResourceSaver.FLAG_BUNDLE_RESOURCES )
	return OK