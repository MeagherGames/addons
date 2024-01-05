@tool
extends EditorImportPlugin

const Aseprite = preload("./Aseprite.gd")

func _get_importer_name(): return "MeagherGames.aseprite.AnimatedSprite2D"

func _get_visible_name(): return "Aseprite Sprite Importer"

func _get_recognized_extensions(): return ["aseprite", "ase"]

func _get_save_extension(): return "tscn"

func _get_resource_type():return "PackedScene"

func _get_preset_count(): return 0

func _get_preset_name(preset:int): return ""

func _get_option_visibility(path: String, option_name:StringName, options: Dictionary) -> bool: return true

func _get_priority(): return 1.0

func _get_import_order(): return IMPORT_ORDER_DEFAULT

func _get_import_options(path:String, preset:int): return []

func _import(source_file, save_path, options, platform_variants, gen_files):
	var aseprite_file = Aseprite.load_file(source_file, options)

	if aseprite_file == null:
		return FAILED
	
	var name = aseprite_file.data.meta.image.split(".")[0]
	var scene:PackedScene = PackedScene.new()
	
	var animation_sprite_2d:AnimatedSprite2D = AnimatedSprite2D.new()
	animation_sprite_2d.name = name

	# Animations
	var sprite_frames:SpriteFrames = SpriteFrames.new()
	animation_sprite_2d.frames = sprite_frames
	for animation_data in aseprite_file.animations:
		if animation.autoplay:
			animation_sprite_2d.animation = animation_data.name
			animation_sprite_2d.autoplay = true
		sprite_frames.add_animation(animation_data.name)
		sprite_frames.set_animation_loop(animation_data.name, true)
		var frames = []
		for frame in range(animation_data.from, animation_data.to + 1):
			var frame_data = aseprite_file.get_frame_data(frame)
			frames.append(frame_data)
		
		if animation_data.direction == "reverse":
			frames = frames.reversed()
		elif animation_data.direction == "pingpong":
			frames = frames + frames[1:-1].reversed()
			
		for frame_data in frames:
			sprite_frames.add_frame(animation_data.name, frame_data.texture, frame_data.duration)
	
	# Done
	scene.pack(animation_sprite_2d)
	return ResourceSaver.save(scene, save_path + "." + _get_save_extension())