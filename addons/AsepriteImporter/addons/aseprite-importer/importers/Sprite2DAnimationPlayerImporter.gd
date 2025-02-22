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
	var aseprite_file = Aseprite.load_file(source_file, options)
	var path = save_path + "." + _get_save_extension()

	if aseprite_file == null:
		return FAILED

	# Todo: Implement split_layers option
	# - use a CanvasGroup to hold the layers
	# - create a Sprite2D for each layer
	# - use the current AnimationPlayer for all layers
	var has_layers = aseprite_file.has_layers()
	
	var root: Node
	if has_layers:
		root = CanvasGroup.new()
		root.fit_margin = 0
		root.clear_margin = 0
	else:
		root = Sprite2D.new()
	
	root.name = aseprite_file.name

	for layer in aseprite_file.layers:
		var sprite_2d: Sprite2D
		if has_layers:
			sprite_2d = add_layer(layer, root, options.get("groups", false)) as Sprite2D
		else:
			sprite_2d = root as Sprite2D
		
		sprite_2d.texture = aseprite_file.texture
		sprite_2d.region_enabled = true
		sprite_2d.region_filter_clip_enabled = true
		sprite_2d.region_rect = layer.region
	
	var animation_player: AnimationPlayer = AnimationPlayer.new()
	var animation_library: AnimationLibrary = AnimationLibrary.new()
	var autoplay_animation = ""

	for ase_animation in aseprite_file.animations:
		var animation: Animation = Animation.new()
		animation.loop_mode = ase_animation.loop_mode
		animation.length = 0.0

		for layer in aseprite_file.layers:
			var data = layer.get_animation_data(ase_animation)
			var frame_track = animation.add_track(Animation.TYPE_VALUE)
			animation.value_track_set_update_mode(frame_track, Animation.UPDATE_DISCRETE)
			animation.track_set_interpolation_loop_wrap(frame_track, false)
			var track_path = ".:region_rect"
			if has_layers:
				var layer_path = get_layer_node_path(layer, options.get("groups", false))
				track_path = "%s:region_rect" % layer_path
			animation.track_set_path(frame_track, track_path)
			
			for i in data.frames.size():
				animation.track_insert_key(
					frame_track,
					data.timing[i],
					data.frames[i].region
				)

			animation.length = max(animation.length, data.length)
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
	var group = layer.group
	if groups and group:
		return "./{group}/{name}".format({
			"group": group,
			"name": layer.name
		})
	
	return "./{name}".format({
		"name": layer.name
	})

func add_layer(layer, root: Node, groups: bool = false) -> Node:
	var group = layer.group
	var layer_node = Sprite2D.new()
	layer_node.name = layer.name
	layer_node.visible = layer.visible

	if groups and group:
		var group_node = root
		for group_name in group.split("/"):
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