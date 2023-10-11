@tool

static func import(aseprite_file, options) -> Node:
	var root
	var sprite
	if options.get("split_layers", false):
		# Viewport textures don't load correctly if they're on the root node
		root = Node3D.new()
		sprite = Sprite3D.new()
		sprite.name = "Sprite3D"
		root.add_child(sprite)
		sprite.owner = root
	else:
		root = Sprite3D.new()
		sprite = root
	
	root.name = options.get("name", "Sprite3D")
	sprite.pixel_size = options.get("pixel_size", 0.01)
	for key in options:
			if key.begins_with("flags/"):
				var flag = key.split("/")[1]
				sprite.set(flag, options[key])

	if options.get("split_layers", false) and aseprite_file.layers.size() > 1:
		# Use subviewport to display multiple layers
		var subviewport = SubViewport.new()
		subviewport.name = "SubViewport"
		subviewport.size = Vector2(aseprite_file.width, aseprite_file.height)
		subviewport.transparent_bg = true
		
		sprite.add_child(subviewport)
		subviewport.owner = root

		var texture = ImageTexture.create_from_image(aseprite_file.image)
		
		for layer in aseprite_file.layers:
			var layer_sprite = Sprite2D.new()
			layer_sprite.name = layer.name
			layer_sprite.texture = texture
			layer_sprite.hframes = aseprite_file.hframes + 1
			layer_sprite.vframes = aseprite_file.vframes + 1
			layer_sprite.frame_coords = layer.start_position
			layer_sprite.centered = false

			subviewport.add_child(layer_sprite)
			layer_sprite.owner = root

		sprite.texture = ViewportTexture.new()
		sprite.texture.viewport_path = root.get_path_to(subviewport)

	else:
		# Use the Sprite3D directly
		var texture = ImageTexture.create_from_image(aseprite_file.image)
		sprite.texture = texture
		sprite.hframes = aseprite_file.hframes + 1
		sprite.vframes = aseprite_file.vframes + 1

	return root

static func setup_animation(sprite:Node, aseprite_file, options) -> Node:
	var animation_player:AnimationPlayer = AnimationPlayer.new()
	var animation_library:AnimationLibrary = AnimationLibrary.new()
	animation_player.name = "AnimationPlayer"

	# each layer contains the animations for that layer
	for animation_data in aseprite_file.animations:
		if animation_data.autoplay || animation_player.autoplay == "":
			# Last animation with this flag will be the one that plays
			# Or the first animation if none have this flag
			animation_player.autoplay = animation_data.name
		
		var animation:Animation
		var max_time:float = 0.0
		if animation_library.has_animation(animation_data.name):
			animation = animation_library.get_animation(animation_data.name)
			max_time = floor(animation.length * 1000.0) / 1000.0
		else:
			animation = Animation.new()
			max_time = 0.0
			animation_library.add_animation(animation_data.name, animation)
		
		match animation_data.direction:
			"forward":
				animation.loop_mode = Animation.LOOP_LINEAR
			"pingpong":
				animation.loop_mode = Animation.LOOP_PINGPONG
			"reverse":
				animation.loop_mode = Animation.LOOP_LINEAR
			_:
				animation.loop_mode = Animation.LOOP_NONE
		
		var user_data_track_index:int = animation.find_track(".", Animation.TYPE_METHOD)
		if user_data_track_index == -1:
			user_data_track_index = animation.add_track(Animation.TYPE_METHOD)
			animation.track_set_path(user_data_track_index, ".")
			animation.track_set_interpolation_type(user_data_track_index, Animation.INTERPOLATION_NEAREST)
		
		for layer_index in aseprite_file.layers.size():
			var layer = aseprite_file.layers[layer_index]
			var layer_path = "."
			if options.get("split_layers", false):
				layer_path = "./Sprite3D/SubViewport/{0}".format([layer.name])

			var track_path:String = layer_path + ":frame_coords"
			var track_index:int = animation.find_track(track_path, Animation.TYPE_VALUE)
			if track_index == -1:
				track_index = animation.add_track(Animation.TYPE_VALUE)
				animation.track_set_path(track_index, track_path)
				animation.track_set_interpolation_type(track_index, Animation.INTERPOLATION_NEAREST)
				animation.value_track_set_update_mode(track_index, Animation.UPDATE_DISCRETE)
			
			var time = max_time
			
			var frames = layer.frames.slice(animation_data.from, animation_data.to + 1)
			if animation_data.direction == "reverse":
				frames.reverse()
			
			for frame in frames:
				if animation.track_find_key(user_data_track_index, time, Animation.FIND_MODE_EXACT) == -1:
					animation.track_insert_key(user_data_track_index, time, {
						method = "set_meta",
						args = ["aseprite_user_data", frame.user_data]
					})
				animation.track_insert_key(track_index, time, Vector2(frame.x, frame.y))
				time += frame.duration
			
			max_time = max(time, max_time)
		
		animation.length = max_time

	animation_player.add_animation_library("", animation_library)
	animation_player.current_animation = animation_player.get_animation_list()[0]

	return animation_player