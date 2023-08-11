extends SpringArm3D

@export var target:Node3D
var yaw_pitch:Vector2 = Vector2.ZERO
var offset:Vector3 = Vector3.ZERO

func _ready():
	offset = position
	top_level = true
	add_excluded_object(target)
	yaw_pitch = Vector2(
		global_rotation_degrees.y,
		global_rotation_degrees.x
	)

func rot(relative:Vector2):
	var current_sensitivity = Vector2(2.0, 2.0)
	yaw_pitch += relative * current_sensitivity
	yaw_pitch.y = clamp(yaw_pitch.y, -70, 70)
	
func _physics_process(_delta):
	var relative = Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if not relative.is_zero_approx():
		rot(-relative) # might adjust for controller sensitivity
	global_position = target.global_transform * offset
	global_rotation_degrees = Vector3(yaw_pitch.y, yaw_pitch.x, 0)

func _notification(what):
	if what == NOTIFICATION_ENTER_TREE:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	elif what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event):
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rot(-event.relative * 0.1)

