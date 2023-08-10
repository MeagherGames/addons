extends Node
class_name CharacterVelocityControl3D

enum JumpState {
	GROUNDED,
	JUMPING,
	FALLING
}

@export var character:CharacterBody3D
@export var stats:CharacterStats3D
@export var jump_buffer_time:float = 0.1

var velocity:Vector3 = Vector3.ZERO
var jump_count:int = 0
var jump_buffer_timer:Timer = Timer.new()
var jump_state:JumpState = JumpState.GROUNDED
var running_strength:float = 0.0

var is_running:bool = false
var is_floating:bool = false :
	set(value):
		if value != is_floating:
			if is_inside_tree():
				if value:
					character.motion_mode = character.MOTION_MODE_FLOATING
					_prev_wall_min_slide_angle = character.wall_min_slide_angle
					character.wall_min_slide_angle = 0.0
				else:
					character.motion_mode = character.MOTION_MODE_GROUNDED
					character.wall_min_slide_angle = _prev_wall_min_slide_angle
	get:
		if is_inside_tree():
			return character.motion_mode == character.MOTION_MODE_FLOATING
		return is_floating
var has_buffered_jump:bool :
	get:
		if is_inside_tree():
			return character.is_on_floor() and not jump_buffer_timer.is_stopped()
		return false

var _has_jumped:bool = false
var _prev_wall_min_slide_angle:float = 0.0
var _ZERO:Vector3 :
	get:
		var zero = character.up_direction
		return zero.normalized()
var _INV_ZERO:Vector3 :
	get:
		return Vector3.ONE - _ZERO


func _enter_tree():
	jump_buffer_timer.one_shot = true
	add_child(jump_buffer_timer)

func _exit_tree():
	remove_child(jump_buffer_timer)

func get_jump_velocity() -> float:
	return (2.0 * stats.jump_height) / stats.jump_time_to_peak

func get_gravity():
	var default_gravity:float = ProjectSettings.get_setting("physics/3d/default_gravity")
	var jump_gravity:float = ((2.0 * stats.jump_height) / (stats.jump_time_to_peak * stats.jump_time_to_peak)) / default_gravity
	var fall_gravity:float = ((2.0 * stats.jump_height) / (stats.jump_time_to_descent * stats.jump_time_to_descent)) / default_gravity
	
	if jump_state == JumpState.JUMPING and velocity.y > 0.0:
		return jump_gravity
	return fall_gravity

func apply_gravity(delta:float):
	var state := PhysicsServer3D.body_get_direct_state(character.get_rid())
	if not character.is_on_floor():
		velocity += (_INV_ZERO * state.total_gravity + _ZERO * state.total_gravity * get_gravity()) * delta

func apply_friction(delta:float):
	var platform_velocity = character.get_platform_velocity()
	var relative_platform_velocity = platform_velocity - velocity

	if (_INV_ZERO * relative_platform_velocity).is_zero_approx():
		velocity = _ZERO * velocity
		is_running = false
		running_strength = 0.0
		return

	var friction:float = 0.0
	if is_on_floor():
		friction = 1.0
		var last_collision = character.get_last_slide_collision()
		if last_collision:
			var collider = last_collision.get_collider()
			if collider is CollisionObject3D:
				var collision_friction:float = PhysicsServer3D.body_get_param(collider.get_rid(), PhysicsServer3D.BODY_PARAM_FRICTION)
				friction = collision_friction
	
	velocity = velocity.move_toward(_ZERO * velocity, stats.deceleration * friction * delta)

func move_in_direction(movement:Vector3, delta:float):
	if movement.is_zero_approx():
		apply_friction(delta)
		is_running = false
		running_strength = 0.0
	else:
		var movement_strength:float = min(movement.length(), 1.0)
		var desired_velocity = movement.normalized() * stats.movement_speed * movement_strength

		if velocity.length_squared() > desired_velocity.length_squared() and is_on_floor():
			velocity = _ZERO * velocity + _INV_ZERO * velocity.move_toward(desired_velocity, stats.deceleration * delta)
		else:
			velocity = _ZERO * velocity + _INV_ZERO * velocity.move_toward(desired_velocity, stats.acceleration * delta)

		running_strength = movement_strength
		is_running = true

func float_in_direction(movement:Vector3, delta):
	if not is_floating:
		is_floating = true

	velocity += movement * stats.movement_speed * delta
	if velocity.is_zero_approx():
		is_running = false
		running_strength = 0.0
	else:
		var movement_strength:float = min(movement.length(), 1.0)
		running_strength = movement_strength
		is_running = true


func steer_in_direction(movement:Vector3, delta:float):
	# like move_in_direction but moves in the forward direction of the character
	# and rotates the character to face the movement direction

	if movement.is_zero_approx():
		apply_friction(delta)
		is_running = false
		running_strength = 0.0
	else:
		# rotate toward movement direction
		xz_rotate_toward(movement, delta) 
		var movement_strength:float = min(movement.length(), 1.0)

		# move in forward direction
		var desired_velocity = -character.global_transform.basis.z.normalized() * movement_strength * stats.movement_speed

		velocity = _ZERO * velocity + _INV_ZERO * desired_velocity
		running_strength = movement_strength
		is_running = true

func can_jump():
	return (
		stats.max_jumps != 0 and
		(not _has_jumped or has_buffered_jump) and
		(stats.max_jumps < 0 or jump_count < stats.max_jumps)
	)

func jump():
	if stats.max_jumps != 0:
		if not _has_jumped or has_buffered_jump:
			_has_jumped = true
			set_deferred("_has_jumped", false)
			jump_buffer_timer.stop()
			if jump_count < stats.max_jumps or stats.max_jumps < 0:
				velocity.y = get_jump_velocity()
				jump_count += 1
				jump_state = JumpState.JUMPING
			else:
				jump_buffer_timer.start(jump_buffer_time)
		pass

func xz_rotate_toward(dir:Vector3, delta:float):
	if dir.is_zero_approx():
		return
	character.rotation.y = lerp_angle(character.rotation.y, atan2(-dir.x, -dir.z), delta * deg_to_rad(360.0 * stats.rotation_speed))

func is_on_floor():
	if is_floating and character.is_on_wall():
		return character.get_wall_normal().dot(character.up_direction) > character.floor_max_angle
	return  character.is_on_floor()

func update_character(delta):
	
	match jump_state:
		JumpState.GROUNDED:
			if not is_on_floor() and velocity.y < 0.0:
				jump_state = JumpState.FALLING
		JumpState.JUMPING:
			if velocity.y < 0.0:
				jump_state = JumpState.FALLING
		JumpState.FALLING:
			if is_on_floor():
				jump_state = JumpState.GROUNDED
			elif velocity.y > 0.0 and not is_floating:
				jump_state = JumpState.JUMPING
	
	var pos:Vector3 = character.global_position
	character.velocity = velocity
	character.move_and_slide()
	var real_velocity = character.get_real_velocity() - character.get_platform_velocity()
	if character.is_on_floor() and character.is_on_ceiling():
		for i in character.get_slide_collision_count():
			var collision = character.get_slide_collision(i)
			var normal = character.up_direction
			var depth = collision.get_depth()
			character.move_and_collide(normal * depth)
	velocity = real_velocity

	if is_on_floor():
		jump_count = 0

func _physics_process(delta):
	apply_gravity(delta)
	update_character(delta)
