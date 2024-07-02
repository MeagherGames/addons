@tool
extends EditorImportPlugin

const Aseprite = preload("res://addons/aseprite-importer/Aseprite/Aseprite.gd")
const DirectionalSprite3D = preload("res://addons/directional_sprite_3d/DirectionalSprite3D.gd")

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

var track_paths_by_direction = {
	"left": ".:left_region",
	"right": ".:right_region",
	"front": ".:front_region",
	"back": ".:back_region",
}

func _parse_directions(animation:Aseprite.AsepriteFile.AsepriteAnimation) -> Dictionary:
	var directions = []
	var flips = []
	var animation_name = animation.name

	for user_data in animation.data:
		if track_paths_by_direction.has(user_data) and user_data not in directions:
			directions.append(user_data)

	# find [left|right|front|back] in the animation name
	# ex: idle [front, back, left, right]
	if animation_name.rfindn("-") >= 0:
		var parts = animation_name.substr(animation_name.rfindn("-") + 1).split(",")
		parts = Array(parts).map(func(x): return x.strip_edges().to_lower())
		for part in parts:
			if track_paths_by_direction.has(part) and part not in directions:
				directions.append(part)

		animation_name = animation_name.substr(0, animation_name.rfind("-"))
	
	for i in directions.size():
		var direction = directions[i]
		if direction == "left" and directions.find("right", i + 1) >= 0:
			flips.append("right")
		if direction == "right" and directions.find("left", i + 1) >= 0:
			flips.append("left")
		if direction == "front" and directions.find("back", i + 1) >= 0:
			flips.append("back")
		if direction == "back" and directions.find("front", i + 1) >= 0:
			flips.append("front")

	return {
		"directions": directions,
		"name": animation_name,
		"flips": flips,
	}

func _import(source_file, save_path, options, platform_variants, gen_files):
	var aseprite_file = Aseprite.load_file(source_file, options)
	var path = save_path + "." + _get_save_extension()

	if aseprite_file == null:
		return FAILED

	if aseprite_file.has_layers():
		printerr("DirectionalSprite3D does not support layers")
		return FAILED
	
	var scene:PackedScene = PackedScene.new()
	# Save an empty scene that will be resaved later
	if ResourceSaver.save(scene, path) != OK:
		return FAILED

	var directional_sprite_3d:DirectionalSprite3D = DirectionalSprite3D.new()
	directional_sprite_3d.name = aseprite_file.name
	directional_sprite_3d.texture = aseprite_file.texture
	directional_sprite_3d.frame_size = aseprite_file.frame_size
	directional_sprite_3d.regions_enabled = true

	# Animations
	var animation_player:AnimationPlayer = AnimationPlayer.new()
	directional_sprite_3d.add_child(animation_player)
	animation_player.name = "AnimationPlayer"
	animation_player.owner = directional_sprite_3d

	# TODO: Implement animations
	# Any animation that ends with `-{left|right|front|back}` will be considered a directional animation
	# directional animations will be grouped by the name before the `-` 
	# The firections will correspond to the regions in the directional sprite 3d
	# and each region will be a track in the animation with the name before the `-` as the animation name

	var animation_library:AnimationLibrary = AnimationLibrary.new()
	animation_player.add_animation_library("", animation_library)
	
	var layer = aseprite_file.layers[0]
	var first_animation_name
	for ase_animation in aseprite_file.animations:
		var parsed = _parse_directions(ase_animation)
		var animation_name = parsed.name
		var directions = parsed.directions
		var flips = parsed.flips


		var animation:Animation
		if animation_library.has_animation(animation_name):
			animation = animation_library.get_animation(animation_name)
		else:
			animation = Animation.new()
			animation_library.add_animation(animation_name, animation)
		
		animation.loop = true
		animation.loop_mode = ase_animation.loop_mode

		if first_animation_name == null:
			first_animation_name = animation_name

		if ase_animation.autoplay:
			first_animation_name = animation_name
			animation_player.autoplay = animation_name

		var track_info = {}
		if directions.size() > 0:
			for direction in directions:
				var track_path = track_paths_by_direction[direction]
				var track_index = animation.find_track(track_path, Animation.TYPE_VALUE)

				if track_index == -1:
					track_index = animation.add_track(Animation.TYPE_VALUE)
					animation.track_set_path(track_index, track_path)

				track_info[track_path] = track_index
		else:
			flips = ["right", "back"]
			for track_path in track_paths_by_direction.values():
				var track_index = animation.find_track(track_path, Animation.TYPE_VALUE)

				if track_index == -1:
					track_index = animation.add_track(Animation.TYPE_VALUE)
					animation.track_set_path(track_index, track_path)

				track_info[track_path] = track_index

		flips = flips.map(func(x): return track_paths_by_direction[x])

		var duration = animation.length
		var animation_data = layer.get_animation_data(ase_animation)
		animation.length = animation_data.length
		for i in animation_data.frames.size():
			var timing = animation_data.timing[i]
			var rect = animation_data.frames[i].region
			var region = Vector4(rect.position.x, rect.position.y, rect.position.x + rect.size.x, rect.position.y + rect.size.y)
			region /= Vector4(
				aseprite_file.size.x,
				aseprite_file.size.y,
				aseprite_file.size.x,
				aseprite_file.size.y
			)
			
			for track_path in track_info:
				var r = Vector4(region.x, region.y, region.z, region.w)
				if flips.has(track_path):
					r.x = r.z
					r.z = region.x
				
				var track_index = track_info[track_path]
				animation.track_insert_key(track_index, timing, r)

				# This is a little ugly but it works
				if animation_name == first_animation_name:
					var property = track_path.split(":")[1]
					directional_sprite_3d.set(property, r)

	scene.pack(directional_sprite_3d)
	# Done
	ResourceSaver.save.call_deferred(scene, path)
	return OK