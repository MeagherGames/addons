@tool
extends RefCounted

class AsepriteFrame extends RefCounted:
	var index: int
	var duration: float
	var region: Rect2
	var position: Vector2
	var user_data: Array

	func _init(index: int, frame_data: Dictionary):
		self.index = index
		self.duration = frame_data.get("duration", 0) / 1000.0
		self.region = Rect2(
			frame_data.frame.x, frame_data.frame.y,
			frame_data.frame.w, frame_data.frame.h
		).abs()
		self.position = Vector2(frame_data.frame.x, frame_data.frame.y)

class AsepriteAnimation extends RefCounted:
	static var AsepriteLoopMode = {
		"forward": Animation.LOOP_LINEAR,
		"reverse": Animation.LOOP_LINEAR,
		"pingpong": Animation.LOOP_PINGPONG,
		"pingpong_reverse": Animation.LOOP_PINGPONG
	}

	var name: String
	var from: int
	var to: int
	var loop_mode: Animation.LoopMode = Animation.LOOP_NONE
	var reverse: bool = false
	var autoplay: bool = false
	var data: PackedStringArray = []

	func _init(animation_data: Dictionary):
		self.name = animation_data.name

		_init_data(animation_data.get("data", ""))

		if animation_data.has("direction"):
			var direction = animation_data.get("direction")
			if not self.data.has("no_loop"):
				self.loop_mode = AsepriteAnimation.AsepriteLoopMode.get(
					direction,
					Animation.LOOP_LINEAR
				)
			self.reverse = direction.ends_with("reverse")
		self.autoplay = animation_data.get("autoplay", false)

		self.from = animation_data.get("from", 0)
		self.to = animation_data.get("to", -1)
		
		if not self.autoplay:
			self.autoplay = self.data.has("autoplay")

	func _init_data(data: String):
		if not data:
			return
		data = data.strip_edges().to_lower()
		if data.find(",") != -1:
			self.data = Array(data.split(",")).map(
				func(s): return s.strip_edges().to_lower()
			).filter(func(s): return s != "")
		elif data:
			self.data = [data]

class AsepriteLayer extends RefCounted:
	var name: String
	var opacity: float
	var blend_mode: String
	var position: Vector2 = Vector2.INF
	var region: Rect2
	var frames: Array[AsepriteFrame] = []
	var group: String = ""
	var visible: bool = true

	func _init(layer_data: Dictionary, extra_data: Dictionary):
		self.name = layer_data.name
		self.opacity = layer_data.get("opacity", 255.0) / 255.0
		self.blend_mode = layer_data.get("blendMode", "normal")
		self.visible = extra_data.get("visible", true) # Aseprite does not give this information by default

	func get_animation_data(animation: AsepriteAnimation) -> Dictionary:
		var frames = []
		var start = animation.from
		var end = animation.to
		if end == -1:
			end = self.frames.size() - 1
		var length = 0.0
		var timing: Array[float] = []
		for i in range(start, end + 1):
			var frame = self.frames[i]
			timing.append(length)
			length += frame.duration
			frames.append(frame)

		if animation.loop_mode == Animation.LOOP_PINGPONG:
			var framse_size = frames.size()
			var reversed_frames = frames.slice(1, frames.size() - 1)
			reversed_frames.reverse()
			frames = frames + reversed_frames
			for i in range(framse_size, frames.size()):
				timing.append(length)
				length += frames[i].duration
		if animation.reverse:
			frames.reverse()
			timing.reverse()
		
		return {
			"frames": frames,
			"length": length,
			"timing": timing
		}
		

var name: String # The name of the sprite sheet
var image: Image # The image of the sprite sheet
var user_data: Array # The user data for the sprite sheet

var texture: Texture2D # The texture of the sprite sheet
var size: Vector2 # The size of the sprite sheet
var frame_size: Vector2 # The size of each frame
var hframes: int = 1 # The number of horizontal frames
var vframes: int = 1 # The number of vertical frames

var layers: Array[AsepriteLayer] # The layers in the sprite sheet
var animations: Array[AsepriteAnimation] # The animations in the sprite sheet

func _init(image: Image, data: Dictionary, extra_data: Dictionary = {}):
	self.name = data.meta.image.split(".")[0]
	self.image = image
	self.user_data = extra_data.get("user_data", [])
	
	texture = ImageTexture.create_from_image(image)
	size = Vector2(data.meta.size.w, data.meta.size.h)

	_init_layers(data, extra_data.get("layer_data", []))
	_init_animations(data)
	_init_frames(data)

func _init_layers(data: Dictionary, extra_layer_data: Array) -> void:
	var ase_group_stack = []
	var ase_group_count = {}

	if data.meta.has("layers"):
		for i in data.meta.layers.size():
			var layer_data = data.meta.layers[i]
			var extra_data = {}
			if extra_layer_data.size() > i:
				extra_data = extra_layer_data[i]
			if layer_data.get("blendMode") == null and layer_data.get("opacity") == null:
				# This a group
				if ase_group_count.has(layer_data.name):
					ase_group_count[layer_data.name] += 1
				else:
					ase_group_count[layer_data.name] = 1
				
				var group_name = layer_data.name
				if ase_group_count[layer_data.name] > 1:
					group_name += str(ase_group_count[layer_data.name])
				ase_group_stack.append(group_name)
			else:
				var group_name = ""
				if layer_data.get("group"):
					# Ensure we're at the right group in the stack
					while ase_group_stack.size() > 0 and not ase_group_stack[-1].begins_with(layer_data.group):
						ase_group_stack.pop_back()
					group_name = "/".join(ase_group_stack)
				else:
					ase_group_stack.clear()
				
				var layer = AsepriteLayer.new(layer_data, extra_data)
				layer.group = group_name
				layers.append(layer)
	else:
		var layer = AsepriteLayer.new({"name": "default"}, {})
		layers.append(layer)

func _init_animations(data: Dictionary) -> void:
	var frame_tags = data.meta.get("frameTags", [])
	
	if frame_tags.size() == 0:
		var animation = AsepriteAnimation.new({
			"name": "RESET",
			"autoplay": true
		})
		animations.append(animation)
	else:
		for tag in frame_tags:
			var animation = AsepriteAnimation.new(tag)
			animations.append(animation)

func _init_frames(data: Dictionary) -> void:
	var frames_per_layer = data.frames.size() / self.layers.size()
	var w: int = int(data.frames[0].frame.w)
	var h: int = int(data.frames[0].frame.h)

	for i in data.frames.size():
		var layer_index = int(i / frames_per_layer)
		var frame_layer_index = i % frames_per_layer
		var frame_data = data.frames[i]
		var hframe = int(frame_data.frame.x) / w + 1
		var vframe = int(frame_data.frame.y) / h + 1

		hframes = max(hframes, hframe)
		vframes = max(vframes, vframe)

		var frame = AsepriteFrame.new(frame_layer_index, frame_data)
		if user_data.size() > frame_layer_index:
			frame.user_data = user_data[frame_layer_index]

		# set layer position
		if not layers[layer_index].position.is_finite():
			layers[layer_index].position = Vector2(hframe, vframe)
		layers[layer_index].frames.append(frame)
		if layers[layer_index].region.size.is_zero_approx():
			layers[layer_index].region = frame.region

	frame_size = Vector2(size.x / hframes, size.y / vframes)

func has_layers() -> bool:
	return layers.size() > 1
