@tool
extends RefCounted

## AsepriteFile is a class that parses the JSON data from an Aseprite file and converts it to a more usable structure

var data:Dictionary ## The raw data from the JSON file
var image:Image ## The sprite sheet image
var texture:Texture2D ## The sprite sheet texture
var width:float ## The width of the sprite sheet
var height:float ## The height of the sprite sheet
var hframes:int ## The number of horizontal frames
var vframes:int ## The number of vertical frames
var layers:Array ## The layers in the sprite sheet
var animations:Array ## The animations in the sprite sheet
var user_data:Array ## The user data for each frame
var sides:Dictionary ## The sides of the sprite sheet

class Tag extends RefCounted:
	var name:String
	var from:int
	var to:int
	var direction:String
	var data:Array[String]
	var autoplay:bool

	func _init(tag:Dictionary):
		self.name = tag.name
		self.from = tag.get("from", 0)
		self.to = tag.get("to", self.from)
		self.direction = tag.get("direction", "forward")
		self.data = []
		self.autoplay = tag.get("autoplay", false)
		
		if tag.get("data", "") != "":
			var items:Array = Array(tag.get("data","").split(",")).map(func(s): return s.strip_edges().to_lower()).filter(func(s): return s != "")
			for item in items:
				if item == "autoplay":
					self.autoplay = true
					continue
				self.data.append(item.strip_edges())

func normalize_animations():
	
	## w and h are the width and height of a single frame
	var w:int = int(data.frames[0].frame.w)
	var h:int = int(data.frames[0].frame.h)
	
	var frame_tags:Array = data.meta.frameTags
	var layer_frames = {}
	var frames_per_layer = data.frames.size() / layers.size()

	for i in data.frames.size():
		var layer_index = int(i / frames_per_layer)
		var frame_layer_index = i % frames_per_layer
		var frame_data = data.frames[i]
		var hframe = int(frame_data.frame.x) / w
		var vframe = int(frame_data.frame.y) / h
		var atlas_texture = AtlasTexture.new()
		
		hframes = max(hframes, hframe)
		vframes = max(vframes, vframe)

		atlas_texture.atlas = texture
		atlas_texture.region = Rect2(frame_data.frame.x, frame_data.frame.y, frame_data.frame.w, frame_data.frame.h)
		

		var frame = {
			duration = frame_data.duration / 1000.0,
			x = hframe,
			y = vframe,
			user_data = user_data[frame_layer_index],
			texture = atlas_texture
		}

		if layers[layer_index].frames.size() == 0:
			layers[layer_index].start_position = Vector2(hframe, vframe)
		layers[layer_index].frames.append(frame)
	
	width /= hframes + 1
	height /= vframes + 1

	animations = []
	if frame_tags.size() == 0:
		animations.append(Tag.new({
			name = "Default",
			direction = "forward",
			from = 0,
			to = data.frames.size() - 1,
			data = "",
			autoplay = true
		}))
	else:
		for tag in frame_tags:
			animations.append(Tag.new(tag))

func normalize() -> void:
	# Takes the raw data and converts it to a more usable structure

	texture = ImageTexture.create_from_image(image)

	width = data.meta.size.w
	height = data.meta.size.h

	# Setup layers
	layers = []
	if data.meta.has("layers"):
		for layer in data.meta.layers:
			layers.append({
				name = layer.name,
				opacity = float(layer.opacity) / 255.0,
				blendMode = layer.blendMode, # Not used but available
				frames = [],
				start_position = Vector2()
			})
	else:
		layers.append({
			name = "Default",
			opacity = 1.0,
			blendMode = "normal",
			frames = [],
			start_position = Vector2()
		})

	normalize_animations()

func get_frame_data(frame:int, layer:int = 0) -> Dictionary:
	# Returns the data for the given frame and layer

	var layer_frames = layers[layer].frames
	var frame_data = layer_frames[frame]
	return frame_data
