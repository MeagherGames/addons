@tool

static func import(aseprite_file, options) -> Node:

	var sprite = Sprite2D.new()
	sprite.name = options.get("name", "Sprite2D")
	var texture = ImageTexture.create_from_image(aseprite_file.image)
	sprite.texture = texture
	sprite.hframes = aseprite_file.hframes + 1
	sprite.vframes = aseprite_file.vframes + 1

	if aseprite_file.layers.size() > 1:
		# Add Sprite2D nodes for each layer except the first
		for i in range(1, aseprite_file.layers.size()):
			var layer = aseprite_file.layers[i]
			var layer_sprite = Sprite2D.new()
			layer_sprite.name = layer.name
			layer_sprite.texture = texture
			layer_sprite.hframes = aseprite_file.hframes + 1
			layer_sprite.vframes = aseprite_file.vframes + 1
			layer_sprite.frame_coords = layer.start_position

			sprite.add_child(layer_sprite)
			layer_sprite.owner = sprite
	
	return sprite

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
		if animation_library.has_animation(animation_data.name):
			animation = animation_library.get_animation(animation_data.name)
		else:
			animation = Animation.new()
			animation.length = 0.0
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
		
		var max_time:float = 0.0
		for layer_index in aseprite_file.layers.size():
			var layer = aseprite_file.layers[layer_index]
			var layer_path = "."
			if options.get("split_layers", false):
				if layer_index > 0:
					layer_path = "./{0}".format([layer.name])

			var track_path:String = layer_path + ":frame_coords"
			var track_index:int = animation.find_track(track_path, Animation.TYPE_VALUE)
			if track_index == -1:
				track_index = animation.add_track(Animation.TYPE_VALUE)
				animation.track_set_path(track_index, track_path)
				animation.track_set_interpolation_type(track_index, Animation.INTERPOLATION_NEAREST)
				animation.value_track_set_update_mode(track_index, Animation.UPDATE_DISCRETE)
			
			var time = animation.length
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