@tool


const BASE_SHADER = preload("../shaders/directional_sprite.gdshader")

const sprite3d = preload("./sprite3d.gd")

static func generate_shader(aseprite_file, options:Dictionary) -> Shader:
	print("Generating directional sprite shader...")

	# #define SHADED
	# #define DOUBLE_SIDED
	# #define NO_DEPTH_TEST
	# #defined FIXED_SIZE

	# #define TRANSPARENCY
	# #define TRANSPARENCY_DISCARD
	# #define TRANSPARENCY_OPAQUE_PREPASS

	# #define FILTER_NEAREST_MIPMAP_ANISOTROPIC
	# #define FILTER_LINEAR_MIPMAP_ANISOTROPIC
	# #define FILTER_NEAREST_MIPMAP
	# #define FILTER_LINEAR_MIPMAP
	# #define FILTER_NEAREST
	# #define FILTER_LINEAR

	# Check flags
	var definitions:PackedStringArray # ex: #define SHADED
	for key in options:
		if key.begins_with("flags/"):
			var flag = key.split("/")[1]
			match flag:
				"shaded": if(options[key]): definitions.append("#define SHADED")
				"double_sided": if(options[key]): definitions.append("#define DOUBLE_SIDED")
				"no_depth_test": if(options[key]): definitions.append("#define NO_DEPTH_TEST")
				"fixed_size": if(options[key]): definitions.append("#define FIXED_SIZE")
				"transparent":
					if options[key]:
						match options["flags/alpha_cut"]:
							Sprite3D.ALPHA_CUT_DISABLED: definitions.append("#define TRANSPARENCY")
							Sprite3D.ALPHA_CUT_DISCARD: definitions.append("#define TRANSPARENCY_DISCARD")
							Sprite3D.ALPHA_CUT_OPAQUE_PREPASS: definitions.append("#define TRANSPARENCY_OPAQUE_PREPASS")
				"texture_filter":
					match options[key]:
						BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS: definitions.append("#define FILTER_NEAREST_MIPMAP")
						BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS: definitions.append("#define FILTER_LINEAR_MIPMAP")
						BaseMaterial3D.TEXTURE_FILTER_NEAREST: definitions.append("#define FILTER_NEAREST")
						BaseMaterial3D.TEXTURE_FILTER_LINEAR: definitions.append("#define FILTER_LINEAR")
						BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS_ANISOTROPIC: definitions.append("#define FILTER_NEAREST_MIPMAP_ANISOTROPIC")
						BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC: definitions.append("#define FILTER_LINEAR_MIPMAP_ANISOTROPIC")
	
	var sides = aseprite_file.sides.keys()
	
	definitions.append("#define SIDE_COUNT " + str(sides.size()))
	for side in sides:
		definitions.append("#define HAS_" + side.to_upper() + " 1")

	var definition_code = "\n".join(definitions)
	
	
	var hash = definition_code.hash()
	var save_path:String = options.get("save_path").get_base_dir()

	var file_path = save_path.path_join("ase_directional_sprite_" + str(hash) + ".gdshader")
	if FileAccess.file_exists(file_path):
		var shader:Shader = ResourceLoader.load(file_path, "Shader")
		if shader:
			print("Loaded shader from cache")
			return shader
	
	var shader = BASE_SHADER.duplicate()
	shader.code = BASE_SHADER.code.replace("#define __DEFINITIONS__", definition_code)
	if ResourceSaver.save(shader, file_path) == OK:
		print("Saved shader to cache")
		shader = ResourceLoader.load(file_path, "Shader")
	else:
		print("Failed to save shader to cache, using in memory shader")
	
	return shader

static func import(aseprite_file, options) -> Node:
	
	var root = Node3D.new()
	root.name = options.get("name", "DirectionalSprite3D")
	var sprite = Sprite3D.new()
	sprite.name = "Sprite3D"
	sprite.pixel_size = options.get("pixel_size", 0.01)
	sprite.hframes = 6
	sprite.vframes = 1
	for key in options:
			if key.begins_with("flags/"):
				var flag = key.split("/")[1]
				sprite.set(flag, options[key])
	
	# We'll always use a subviewport to display a directional sprite
	var subviewport = SubViewport.new()
	subviewport.name = "SubViewport"
	subviewport.transparent_bg = true
	subviewport.size.x = aseprite_file.width * 6
	subviewport.size.y = aseprite_file.height
	
	root.add_child(sprite)
	sprite.owner = root
	sprite.add_child(subviewport)
	subviewport.owner = root

	var texture = ImageTexture.create_from_image(aseprite_file.image)

	var shader = generate_shader(aseprite_file, options)
	var material = ShaderMaterial.new()
	var material_id = material.get_rid()
	sprite.material_override = material
	material.resource_local_to_scene = true
	material.shader = shader
	material.set("shader_parameter/size", Vector2(
		1.0 / 6.0,
		1.0
	))

	var viewport_texture = ViewportTexture.new()
	sprite.texture = viewport_texture
	sprite.texture.viewport_path = root.get_path_to(subviewport)
	
	# If we're doing a directional sprite, we need to make a sprite for each side
	# and then use a subviewport to display them all at once
	# Directional sprites should also support layers
	# We'll use the shader paramters on the Sprite3D to control the offset and scale of each side
	# tags can have user_data with left, right, top, bottom, front, back
	# the same tag can be used for multiple sides, if there is a colon after the side name
	# well look for numbers to do the frame scale ex: left:-1.0:1.0 (name:x:y)
	# the shader also needs to be generated with the flags since we had to reimplement the default shader with our own changes
	
	var sprite_uv_offset = Vector2(1.0/6.0, 0.0)
	var sides = aseprite_file.sides.keys()
	for i in sides.size():
		# create a node 2D for each side
		# offset the node by it's index
		var side = sides[i]
		var details = aseprite_file.sides[side]
		var first_animation = details.values()[0]
		
		var node
		if options.get("split_layers", false) and aseprite_file.layers.size() > 1:
			node = Node2D.new()
			node.name = side
			# add the node to the subviewport
			subviewport.add_child(node)
			node.owner = root
			for layer in aseprite_file.layers:
				var layer_sprite = Sprite2D.new()
				layer_sprite.name = layer.name
				layer_sprite.texture = texture
				layer_sprite.centered = false
				layer_sprite.hframes = aseprite_file.hframes + 1
				layer_sprite.vframes = aseprite_file.vframes + 1
				
				var frame = layer.frames[first_animation.tag.from]
				layer_sprite.frame_coords = Vector2(frame.x, frame.y)

				node.add_child(layer_sprite)
				layer_sprite.owner = root

		else:
			node = Sprite2D.new()
			node.name = side
			# add the node to the subviewport
			subviewport.add_child(node)
			node.owner = root
			node.texture = texture
			node.centered = false
			node.hframes = aseprite_file.hframes + 1
			node.vframes = aseprite_file.vframes + 1

			var frame = aseprite_file.layers[0].frames[first_animation.tag.from]
			node.frame_coords = Vector2(frame.x, frame.y)
		
		node.position.x = aseprite_file.width * i
		node.position.y = 0
		
		var offset_path = "shader_parameter/{0}_offset".format([side])
		var offset = sprite_uv_offset * i
		material.set(offset_path, offset)

		var scale_path = "shader_parameter/{0}_scale".format([side])
		
		material.set(scale_path, first_animation.scale)
	
	material.set("shader_parameter/texture_albedo", viewport_texture)
	
	return root

static func setup_animation(sprite:Node, aseprite_file, options) -> Node:
	# I need to setup animations for each side
	# I also need to setup the animation player
	# sides could have multiple animations
	# we need to play animations with the same name for every side that has it

	var animation_player = AnimationPlayer.new()
	var animation_library = AnimationLibrary.new()
	animation_player.name = "AnimationPlayer"

	# each side contains the animations for that side
	# we'll also need to handle if there are layers

	for side in aseprite_file.sides:
		var details = aseprite_file.sides[side]
		for side_animation_data in details.values():
			var tag = side_animation_data.tag
			var scale = side_animation_data.scale
			if tag.autoplay or animation_player.autoplay == "":
				# Last animation with this flag will be the one that plays
				# Or the first animation if none have this flag
				animation_player.autoplay = tag.name
			
			var animation:Animation
			var max_time:float = 0.0
			if animation_library.has_animation(tag.name):
				animation = animation_library.get_animation(tag.name)
				max_time = floor(animation.length * 1000.0) / 1000.0
			else:
				animation = Animation.new()
				animation_library.add_animation(tag.name, animation)

			match tag.direction:
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
				var layer_path = "./Sprite3D/SubViewport/{0}".format([side])
				if options.get("split_layers", false) and aseprite_file.layers.size() > 1:
					layer_path += "/{0}".format([layer.name])

				var track_path:String = "{0}:frame_coords".format([layer_path])
				var track_index:int = animation.find_track(track_path, Animation.TYPE_VALUE)
				if track_index == -1:
					track_index = animation.add_track(Animation.TYPE_VALUE)
					animation.track_set_path(track_index, track_path)
					animation.track_set_interpolation_type(track_index, Animation.INTERPOLATION_NEAREST)
					animation.value_track_set_update_mode(track_index, Animation.UPDATE_DISCRETE)

				var time = 0.0
				var frames = layer.frames.slice(tag.from, tag.to + 1)
				if tag.direction == "reverse":
					frames.reverse()

				for frame in frames:
					if animation.track_find_key(user_data_track_index, time, Animation.FIND_MODE_EXACT) == -1:
						animation.track_insert_key(user_data_track_index, time,{
							method =  "set_meta",
							args = ["aseprite_user_data", frame.user_data]
						})
					animation.track_insert_key(track_index, time, Vector2(frame.x, frame.y))
					time += frame.duration
				
				max_time = max(max_time, time)
			
			animation.length = max_time
		
	animation_player.add_animation_library("", animation_library)
	animation_player.current_animation = animation_player.get_animation_list()[0]

	return animation_player
