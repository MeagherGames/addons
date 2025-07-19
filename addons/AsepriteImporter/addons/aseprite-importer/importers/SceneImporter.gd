@tool
extends EditorImportPlugin

const Aseprite = preload("res://addons/aseprite-importer/Aseprite/Aseprite.gd")

func _get_importer_name(): return "MeagherGames.aseprite.Scene"

func _get_visible_name(): return "Aseprite Scene Importer"

func _get_recognized_extensions(): return ["aseprite", "ase"]

func _get_save_extension(): return "tscn"

func _get_resource_type(): return "PackedScene"

func _get_preset_count(): return 1

func _get_import_order(): return 0

func _get_priority(): return 1

func _get_preset_name(_preset: int): return "Default"

func _get_import_options(path: String, _preset: int) -> Array[Dictionary]:
	var file_dir = path.get_base_dir()
	var file_name = path.get_basename().get_file()
	return [
		{
			"name": "export_tileset",
			"default_value": true
		},
		{
			"name": "tile_set_path",
			"default_value": file_dir.path_join(file_name + "_tileset.tres"),
			"hint": PROPERTY_HINT_FILE,
			"hint_string": "*.tres",
		}
	]

func _get_option_visibility(path: String, option_name: StringName, options: Dictionary) -> bool:
	return true

func _import(source_file, save_path, options, _platform_variants, _gen_files):
	options.layers = true
	options.tiles = true
	# options.debug = true
	var data = Aseprite.load_file(source_file, options)
	var path = save_path + "." + _get_save_extension()

	if data.is_empty():
		return FAILED

	var atlas_texture = ImageTexture.create_from_image(Image.load_from_file(data.meta.atlas_path))

	var root: Node
	if data.layers.size() > 1:
		root = CanvasGroup.new()
		root.fit_margin = 0
		root.clear_margin = 0

		for layer in data.layers:
			var layer_node = create_layer(layer, atlas_texture, data.tile_sets, options)
			if options.get("groups", false):
				group_node(layer.group, layer_node, root)
			else:
				root.add_child(layer_node, true)
				layer_node.owner = root
	else:
		root = create_layer(data.layers[0], atlas_texture, data.tile_sets, options)
		

	root.name = data.meta.name

	var animation_player: AnimationPlayer = AnimationPlayer.new()
	var animation_library: AnimationLibrary = AnimationLibrary.new()
	var autoplay_animation = ""

	for animation_data in data.animations:
		var animation: Animation = Animation.new()
		animation.loop_mode = animation_data.loop_mode
		animation.length = animation_data.duration

		for layer in data.layers:
			animate_layer(animation_data, layer, animation, data.layers.size() > 1)

		animation_library.add_animation(animation_data.name, animation)
		if animation_data.autoplay:
			autoplay_animation = animation_data.name

	animation_player.add_animation_library("", animation_library)
	
	root.add_child(animation_player, true)
	animation_player.owner = root
	animation_player.current_animation = autoplay_animation
	animation_player.autoplay = autoplay_animation
	
	var scene: PackedScene = PackedScene.new()
	var result = scene.pack(root)
	return ResourceSaver.save(scene, path)

func get_layer_node_path(layer) -> String:
	if layer.group.size() > 0:
		return "./{group}/{name}".format({
			"group": "/".join(layer.group),
			"name": layer.name
		})
	return "./{name}".format({
		"name": layer.name
	})

func create_sprite_layer(layer: Dictionary, atlas_texture: Texture, options: Dictionary) -> Node2D:
	var layer_node = Sprite2D.new()
	layer_node.name = layer.name
	layer_node.centered = false
	layer_node.visible = layer.visible
	layer_node.texture = atlas_texture
	layer_node.region_enabled = true
	layer_node.region_filter_clip_enabled = true
	layer_node.region_rect = Rect2(
		layer.frames[0].region.x,
		layer.frames[0].region.y,
		layer.frames[0].region.w,
		layer.frames[0].region.h
	)
	layer_node.offset = Vector2(
		layer.frames[0].position.x,
		layer.frames[0].position.y
	)

	return layer_node

func create_tile_set_source(tile_set_data: Dictionary, atlas_texture: Texture) -> TileSetAtlasSource:
	var tile_set_texture = AtlasTexture.new()
	tile_set_texture.atlas = atlas_texture
	tile_set_texture.region = Rect2(
		tile_set_data.region.x,
		tile_set_data.region.y,
		tile_set_data.region.w,
		tile_set_data.region.h
	)
	var tile_set_source = TileSetAtlasSource.new()
	tile_set_source.resource_name = tile_set_data.name
	tile_set_source.use_texture_padding = false
	tile_set_source.texture = tile_set_texture
	tile_set_source.texture_region_size = Vector2(
		tile_set_data.grid.w,
		tile_set_data.grid.h
	)

	for tile_pos in tile_set_data.tiles:
		tile_set_source.create_tile(Vector2i(tile_pos.x, tile_pos.y))

	tile_set_source.set_meta("is_aseprite_tileset", true)
	return tile_set_source

func create_tile_set(tile_set_data: Dictionary, atlas_texture: Texture) -> TileSet:
	var tile_set = TileSet.new()
	tile_set.tile_layout = TileSet.TILE_LAYOUT_STACKED
	tile_set.tile_offset_axis = TileSet.TILE_OFFSET_AXIS_HORIZONTAL
	tile_set.tile_shape = TileSet.TILE_SHAPE_SQUARE
	tile_set.uv_clipping = true
	tile_set.tile_size = Vector2(tile_set_data.grid.w, tile_set_data.grid.h)
	return tile_set

func update_tile_set_source(tile_set_source: TileSetAtlasSource, tile_set_data: Dictionary, atlas_texture: Texture) -> void:
	var tile_set_texture = AtlasTexture.new()
	tile_set_texture.atlas = atlas_texture
	tile_set_texture.region = Rect2(
		tile_set_data.region.x,
		tile_set_data.region.y,
		tile_set_data.region.w,
		tile_set_data.region.h
	)
	tile_set_source.texture = tile_set_texture

func create_tile_map_layer(layer: Dictionary, atlas_texture: Texture, tile_sets: Array, options: Dictionary) -> Node2D:
	var layer_node: TileMapLayer = TileMapLayer.new()
	layer_node.name = layer.name
	layer_node.visible = layer.visible

	var tile_set: TileSet = null
	var tile_set_path = options.get("tile_set_path", "")
	if options.get("export_tileset", true) and not tile_set_path == "" and FileAccess.file_exists(tile_set_path):
		tile_set = load(tile_set_path)
	
	var tile_set_data = tile_sets[layer.tile_set]
	var tile_set_source_id: int = 0

	if tile_set == null:
		tile_set = create_tile_set(tile_set_data, atlas_texture)
		var tile_set_source = create_tile_set_source(tile_set_data, atlas_texture)
		tile_set_source_id = tile_set.add_source(tile_set_source)
	else:
		# find tile_set_source with metadata
		tile_set_source_id = 0
		var tile_set_source: TileSetAtlasSource = null
		for i in tile_set.get_source_count():
			var source_id = tile_set.get_source_id(i)
			tile_set_source = tile_set.get_source(source_id)
			if tile_set_source is TileSetAtlasSource and tile_set_source.get_meta("is_aseprite_tileset", false):
				tile_set_source_id = source_id
		
		if tile_set_source == null or not tile_set_source is TileSetAtlasSource:
			tile_set_source = create_tile_set_source(tile_set_data, atlas_texture)
			tile_set_source_id = tile_set.add_source(tile_set_source)
		else:
			update_tile_set_source(tile_set_source, tile_set_data, atlas_texture)
	
	if options.get("export_tileset", true):
		ResourceSaver.save(tile_set, tile_set_path)
		
	layer_node.tile_set = tile_set
	var size: Vector2i = Vector2i(
		layer.frames[0].region.w,
		layer.frames[0].region.h
	)
	
	for i in layer.frames[0].tiles.size():
		var tile: int = layer.frames[0].tiles[i]
		var coords = Vector2i(
			(i % size.x) + layer.frames[0].region.x,
			(i / size.x) + layer.frames[0].region.y
		)

		if tile == 0:
			# Don't need to clear the cell, as it is already empty, but this is the code
			# layer_node.set_cell(coords, -1, -Vector2i.ONE, -1)
			continue
		
		var tile_id: int = (tile & 0x1fffffff) - 1
		var flip_h: bool = tile & 0x80000000 != 0
		var flip_v: bool = tile & 0x40000000 != 0
		var transpose: bool = tile & 0x20000000 != 0

		var tile_coords = Vector2i(
			tile_set_data.tiles[tile_id].x,
			tile_set_data.tiles[tile_id].y
		)

		var alternative_id: int = 0
		if flip_h:
			alternative_id |= TileSetAtlasSource.TRANSFORM_FLIP_H
		if flip_v:
			alternative_id |= TileSetAtlasSource.TRANSFORM_FLIP_V
		if transpose:
			alternative_id |= TileSetAtlasSource.TRANSFORM_TRANSPOSE
	
		layer_node.set_cell(coords, tile_set_source_id, tile_coords, alternative_id)

	return layer_node


func create_layer(layer: Dictionary, texture: Texture, tile_sets: Array, options: Dictionary) -> Node2D:
	if layer.is_tilemap:
		return create_tile_map_layer(layer, texture, tile_sets, options)
	else:
		return create_sprite_layer(layer, texture, options)

func group_node(group: Array[String], layer_node: Node2D, root: Node) -> void:
	if group.size() > 0:
		var group_node = root
		for group_name in group:
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


func animate_sprite_layer(animation_data: Dictionary, animation: Animation, layer_data: Dictionary, has_layers: bool = false) -> void:
	var region_frame_track = animation.add_track(Animation.TYPE_VALUE)
	animation.value_track_set_update_mode(region_frame_track, Animation.UPDATE_DISCRETE)
	animation.track_set_interpolation_loop_wrap(region_frame_track, false)

	var offset_frame_track = animation.add_track(Animation.TYPE_VALUE)
	animation.value_track_set_update_mode(offset_frame_track, Animation.UPDATE_DISCRETE)
	animation.track_set_interpolation_loop_wrap(offset_frame_track, false)

	var region_track_path = ".:region_rect"
	var offset_frame_track_path = ".:offset"
	if has_layers:
		region_track_path = "%s:region_rect" % get_layer_node_path(layer_data)
		offset_frame_track_path = "%s:offset" % get_layer_node_path(layer_data)

	animation.track_set_path(region_frame_track, region_track_path)
	animation.track_set_path(offset_frame_track, offset_frame_track_path)

	var timing = 0
	for frame in layer_data.frames:
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
				frame.position.x,
				frame.position.y
			)
		)
		timing += frame.duration

func animate_tile_map_layer(animation_data: Dictionary, animation: Animation, layer_data: Dictionary, has_layers: bool = false) -> void:
	# Tilemap animations are not implemented yet
	pass

func animate_layer(animation_data: Dictionary, layer_data: Dictionary, animation: Animation, has_layers: bool = false) -> void:
	if layer_data.is_tilemap:
		animate_tile_map_layer(animation_data, animation, layer_data, has_layers)
	else:
		animate_sprite_layer(animation_data, animation, layer_data, has_layers)
