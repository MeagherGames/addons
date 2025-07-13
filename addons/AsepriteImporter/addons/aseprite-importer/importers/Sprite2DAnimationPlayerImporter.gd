@tool
extends EditorImportPlugin

const Aseprite = preload("res://addons/aseprite-importer/Aseprite/Aseprite.gd")

func _get_importer_name(): return "MeagherGames.aseprite.Sprite2DAnimationPlayer"

func _get_visible_name(): return "Aseprite Sprite2DAnimationPlayer Importer"

func _get_recognized_extensions(): return ["aseprite", "ase"]

func _get_save_extension(): return "tscn"

func _get_resource_type(): return "PackedScene"

func _get_preset_count(): return 1

func _get_import_order(): return 0

func _get_priority(): return 1

func _get_preset_name(_preset: int): return "Default"

func _get_import_options(_path: String, _preset: int) -> Array[Dictionary]:
	return [
		{
			"name": "split_layers",
			"default_value": false,
		},
		{
			"name": "groups",
			"default_value": true,
		}
	]

func _get_option_visibility(path: String, option_name: StringName, options: Dictionary) -> bool:
	if option_name == "groups":
		return options.get("split_layers", false)
	return true

func _import(source_file, save_path, options, _platform_variants, _gen_files):
	options.layers = options.get("split_layers", false) # backwards compatibility with old importer
	options.tiles = false
	var aseprite_file = Aseprite.load_file(source_file, options)
	var path = save_path + "." + _get_save_extension()

	if aseprite_file.is_empty():
		return FAILED

	var has_layers = aseprite_file.layers.size() > 1
	var root: Node
	if has_layers:
		root = CanvasGroup.new()
		root.fit_margin = 0
		root.clear_margin = 0
	else:
		root = Sprite2D.new()
	
	root.name = aseprite_file.meta.name
	var atlas_texture = ImageTexture.create_from_image(Image.load_from_file(aseprite_file.meta.atlas_path))

	for layer in aseprite_file.layers:
		var sprite_2d: Sprite2D
		if has_layers:
			sprite_2d = add_layer(layer, root, options.get("groups", false)) as Sprite2D
		else:
			sprite_2d = root as Sprite2D
		
		sprite_2d.texture = atlas_texture
		sprite_2d.region_enabled = true
		sprite_2d.region_filter_clip_enabled = true
		sprite_2d.region_rect = Rect2(
			layer.frames[0].region.x,
			layer.frames[0].region.y,
			layer.frames[0].region.w,
			layer.frames[0].region.h
		)
		sprite_2d.offset = Vector2(
			layer.frames[0].position.x / 2,
			layer.frames[0].position.y / 2
		)
	
	var animation_player: AnimationPlayer = AnimationPlayer.new()
	var animation_library: AnimationLibrary = AnimationLibrary.new()
	var autoplay_animation = ""

	for ase_animation in aseprite_file.animations:
		var animation: Animation = Animation.new()
		animation.loop_mode = ase_animation.loop_mode
		animation.length = ase_animation.duration

		for layer in aseprite_file.layers:
			var region_frame_track = animation.add_track(Animation.TYPE_VALUE)
			animation.value_track_set_update_mode(region_frame_track, Animation.UPDATE_DISCRETE)
			animation.track_set_interpolation_loop_wrap(region_frame_track, false)

			var offset_frame_track = animation.add_track(Animation.TYPE_VALUE)
			animation.value_track_set_update_mode(offset_frame_track, Animation.UPDATE_DISCRETE)
			animation.track_set_interpolation_loop_wrap(offset_frame_track, false)

			var region_track_path = ".:region_rect"
			var offset_frame_track_path = ".:offset"
			if has_layers:
				var layer_path = get_layer_node_path(layer, options.get("groups", false))
				region_track_path = "%s:region_rect" % layer_path
				offset_frame_track_path = "%s:offset" % layer_path
			animation.track_set_path(region_frame_track, region_track_path)
			animation.track_set_path(offset_frame_track, offset_frame_track_path)

			var timing = 0
			var frames = layer.frames.slice(ase_animation.from, ase_animation.to + 1)
			for frame in frames:
				animation.track_insert_key(
					region_frame_track,
					timing,
					Rect2(
						frame.region.x,
						frame.region.y,
						frame.region.w,
						frame.region.h
					)
				)
				animation.track_insert_key(
					offset_frame_track,
					timing,
					Vector2(
						frame.position.x / 2,
						frame.position.y / 2
					)
				)
				timing += frame.duration

		animation_library.add_animation(ase_animation.name, animation)
		if ase_animation.autoplay:
			autoplay_animation = ase_animation.name

	animation_player.add_animation_library("", animation_library)
	
	root.add_child(animation_player, true)
	animation_player.owner = root
	animation_player.current_animation = autoplay_animation
	animation_player.autoplay = autoplay_animation
	
	var scene: PackedScene = PackedScene.new()
	var result = scene.pack(root)
	return ResourceSaver.save(scene, path)

func get_layer_node_path(layer, groups: bool = false) -> String:
	if groups and layer.group.size() > 0:
		return "./{group}/{name}".format({
			"group": "/".join(layer.group),
			"name": layer.name
		})
	
	return "./{name}".format({
		"name": layer.name
	})

func add_layer(layer, root: Node, groups: bool = false) -> Node:
	var layer_node = Sprite2D.new()
	layer_node.name = layer.name
	layer_node.visible = layer.visible

	if groups and layer.group.size() > 0:
		var group_node = root
		for group_name in layer.group:
			var next_group = group_node.get_node_or_null(group_name)
			if next_group == null:
				next_group = Node2D.new()
				next_group.name = group_name
				group_node.add_child(next_group, true)
				next_group.owner = root
			group_node = next_group
		group_node.add_child(layer_node, true)
		layer_node.owner = root
	else:
		root.add_child(layer_node, true)
		layer_node.owner = root

	return layer_node