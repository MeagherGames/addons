@tool
extends AtlasTexture

const PROCESS_MODE_IDLE = 0
const PROCESS_MODE_PHYSICS = 1
const PROCESS_MODE_MANUAL = 2

@export_enum("idle:0", "physics:1", "manual:2") var process_mode: int = PROCESS_MODE_IDLE: set = set_process_mode
@export_storage var aseprite_data: Dictionary = {}
@export_storage var _current_animation: String = ""
@export_storage var _current_frame: int = 0

var _current_animation_data: Dictionary = {}
var _start: float = 0.0
var _time: float = 0.0
var _direction: int = 1

func _init() -> void:
	filter_clip = true
	_start = Time.get_unix_time_from_system()
	set_process_mode(process_mode)

func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	# Current animation should be a dropdown of available animations
	# Current frame should be an integer slider from 0 to number of frames in current animation - 1
	if aseprite_data.has("animations"):
		var animation_names: Array[String] = get_animations()
		if _current_animation == "" and animation_names.size() > 0:
			_current_animation = animation_names[0]
			_current_frame = 0
		properties.append({
			"name": "current_animation",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": ",".join(animation_names),
			"default_value": _current_animation,
			"property_usage": PROPERTY_USAGE_DEFAULT,
		})
		var frame_count: int = get_frame_count(_current_animation)
		properties.append({
			"name": "current_frame",
			"type": TYPE_INT,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "0,%d" % max(frame_count - 1, 0),
			"default_value": _current_frame,
			"property_usage": PROPERTY_USAGE_DEFAULT,
		})
	return properties

func _set(property: StringName, value) -> bool:
	if property == "current_animation":
		set_animation(value)
		return true
	elif property == "current_frame":
		_current_frame = clamp(value, 0, _current_animation_data.get("to", 0) - _current_animation_data.get("from", 0))
		_update_region()
		return true
	return false

func _get(property: StringName):
	if property == "current_animation":
		return _current_animation
	elif property == "current_frame":
		return _current_frame
	return null

func _get_current_frame_data() -> Dictionary:
	if not aseprite_data.has("animations") or not aseprite_data.has("layers"):
		return {}
	
	var frames_data: Array = aseprite_data.layers[0].frames
	if _current_animation_data.is_empty():
		return {}
	
	var frame_index: int = _current_animation_data.from + _current_frame
	if frame_index < 0 or frame_index >= frames_data.size():
		return {}
	
	return frames_data[frame_index]

func _update_region() -> void:
	if not aseprite_data.has("animations") or not aseprite_data.has("layers"):
		return
	
	# There will only be 1 layer for Texture2D imports
	var current_frame_data: Dictionary = _get_current_frame_data()
	if current_frame_data.is_empty():
		return
	
	region = Rect2(
		current_frame_data.region.x,
		current_frame_data.region.y,
		current_frame_data.region.w,
		current_frame_data.region.h
	)

func _process() -> void:
	var delta = Time.get_unix_time_from_system() - _start
	_start = Time.get_unix_time_from_system()

	if not aseprite_data.has("animations") or not aseprite_data.has("layers"):
		return
	
	if _current_animation_data.is_empty():
		return

	_time += delta
	var frames_data: Array = aseprite_data.layers[0].frames
	var current_frame_data: Dictionary = _get_current_frame_data()
	if current_frame_data.is_empty():
		return
	if _time >= current_frame_data.duration:
		_time = 0.0
		_current_frame += _direction

		# make sure to account for the current direction when checking loop modes
		match int(_current_animation_data.get("loop_mode", 0)):
			Animation.LOOP_NONE:
				_current_frame = clamp(_current_frame, 0, _current_animation_data.to - _current_animation_data.from)
			Animation.LOOP_LINEAR:
				if _current_frame > (_current_animation_data.to - _current_animation_data.from):
					_current_frame = 0
				elif _current_frame < 0:
					_current_frame = _current_animation_data.to - _current_animation_data.from
					
			Animation.LOOP_PINGPONG:
				if _current_frame > (_current_animation_data.to - _current_animation_data.from):
					_current_frame = (_current_animation_data.to - _current_animation_data.from) - 1
					_direction *= -1
				elif _current_frame < 0:
					_current_frame = 0
					_direction *= -1
		
		_update_region()

func _get_animation_data(animation_name: String) -> Dictionary:
	if aseprite_data.has("animations"):
		for animation_data in aseprite_data.animations:
			if animation_data.get("name", "") == animation_name:
				return animation_data
	return {}

func set_animation(animation_name: String) -> void:
	if animation_name == _current_animation and _current_animation_data.get("name", "") == animation_name:
		return
	_current_animation = animation_name
	_current_frame = 0
	_current_animation_data = _get_animation_data(animation_name)
	_direction = -1 if _current_animation_data.get("reverse", false) else 1
	_start = Time.get_unix_time_from_system()
	_update_region()
	print("Set animation to ", _current_animation, " with data: ", _current_animation_data)

func get_animations() -> Array[String]:
	var result: Array[String] = []
	if aseprite_data.has("animations"):
		for animation_data in aseprite_data.animations:
			result.append(animation_data.name)
	return result

func get_frame_count(animation_name: String) -> int:
	var animation_data = _get_animation_data(animation_name)
	if not animation_data.is_empty():
		return animation_data.to - animation_data.from
	return 0

func set_process_mode(value: int) -> void:
	if process_mode == PROCESS_MODE_IDLE and Engine.get_main_loop().process_frame.is_connected(_process):
		Engine.get_main_loop().process_frame.disconnect(_process)
	elif process_mode == PROCESS_MODE_PHYSICS and Engine.get_main_loop().physics_frame.is_connected(_process):
		Engine.get_main_loop().physics_frame.disconnect(_process)

	process_mode = value

	if process_mode == PROCESS_MODE_IDLE:
		Engine.get_main_loop().process_frame.connect(_process)
	elif process_mode == PROCESS_MODE_PHYSICS:
		Engine.get_main_loop().physics_frame.connect(_process)
	emit_changed()

func advance(delta: float) -> void:
	_start = Time.get_unix_time_from_system() - delta
	_process()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		set_process_mode(PROCESS_MODE_MANUAL)
