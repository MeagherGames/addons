extends State

@export var velocity_control:CharacterVelocityControl3D
@export var rotate_toward_velocity:bool = true # TODO move this to it's own state

var air_slide:bool = true
var first_floor_bump:bool = false

func enter():
	air_slide = true
	first_floor_bump = false

func physics_update(delta):

	var movement:Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var movement_strength:float = min(movement.length(), 1.0)
	var camera_basis:Basis = get_viewport().get_camera_3d().get_camera_transform().basis
	var force = camera_basis * Vector3(movement.x, 0.0, movement.y)
	force = force.slide(Vector3.UP).normalized() * movement_strength
	
	if rotate_toward_velocity:
		velocity_control.xz_rotate_toward(force, delta)

	if not is_zero_approx(movement_strength):
		air_slide = false
	
	if not air_slide:
		velocity_control.move_in_direction(force, delta)
	
	if velocity_control.character.is_on_floor():
		if first_floor_bump:
			air_slide = false
		first_floor_bump = true

	if Input.is_action_just_pressed("jump"):
		velocity_control.jump()
		air_slide = true
		first_floor_bump = false
