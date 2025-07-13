@tool
extends EditorImportPlugin

const Aseprite = preload("res://addons/aseprite-importer/Aseprite/Aseprite.gd")

func _get_importer_name(): return "MeagherGames.aseprite.AnimatedSprite2D"

func _get_visible_name(): return "Aseprite AnimatedSprite2D Importer"

func _get_recognized_extensions(): return ["aseprite", "ase"]

func _get_save_extension(): return "tscn"

func _get_resource_type(): return "PackedScene"

func _get_preset_count(): return 1

func _get_import_order(): return 0

func _get_priority(): return 1

func _get_preset_name(_preset: int): return "Default"

func _get_import_options(_path: String, _preset: int): return []

func _get_option_visibility(path: String, option_name: StringName, options: Dictionary): return false

func _import(source_file, save_path, options, _platform_variants, _gen_files):
	options.layers = false
	var data: Dictionary = Aseprite.load_file(source_file, options)
	var path = save_path + "." + _get_save_extension()

	if data.is_empty():
		return FAILED

	if data.layers.size() > 1:
		printerr("AnimatedSprite2D does not support layers")
		return FAILED

	var animation_sprite_2d: AnimatedSprite2D = AnimatedSprite2D.new()
	animation_sprite_2d.name = data.meta.name

	# Animations
	var sprite_frames: SpriteFrames = SpriteFrames.new()
	sprite_frames.remove_animation("default")
	
	var atlas_texture = ImageTexture.create_from_image(Image.load_from_file(data.meta.atlas_path))
	
	# Only support one layer for now
	var layer = data.layers[0]
	
	for ase_animation in data.animations:
		sprite_frames.add_animation(ase_animation.name)
		sprite_frames.set_animation_loop(ase_animation.name, ase_animation.loop_mode != Animation.LOOP_NONE)
		sprite_frames.set_animation_speed(ase_animation.name, 1.0)

		if ase_animation.autoplay:
			animation_sprite_2d.autoplay = StringName(ase_animation.name)

		var frames = layer.frames.slice(ase_animation.from, ase_animation.to + 1)
		if ase_animation.loop_mode == Animation.LOOP_PINGPONG:
			var reversed_frames = frames.slice(1, frames.size() - 1)
			reversed_frames.reverse()
			frames = frames + reversed_frames
		if ase_animation.reverse:
			frames.reverse()

		for frame_data in frames:
			var texture = AtlasTexture.new()
			texture.atlas = atlas_texture
			texture.filter_clip = true
			texture.margin = Rect2(
				frame_data.position.x,
				frame_data.position.y,
				data.width - frame_data.region.w,
				data.height - frame_data.region.h
			)
			texture.region = Rect2(
				frame_data.region.x,
				frame_data.region.y,
				frame_data.region.w,
				frame_data.region.h
			)
			sprite_frames.add_frame(ase_animation.name, texture, frame_data.duration)

	animation_sprite_2d.frames = sprite_frames

	var scene: PackedScene = PackedScene.new()
	scene.pack(animation_sprite_2d)
	return ResourceSaver.save(scene, path)