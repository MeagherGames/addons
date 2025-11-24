extends RefCounted
class_name Spring

var stiffness:float = 1.0
var damping:float = 0.1
var velocity:Vector3 = Vector3.ZERO
var rest_position:Vector3 = Vector3.ZERO

func _init(rest_position:Vector3 = Vector3.ZERO, stiffness:float = 1.0, damping:float = 0.1):
    self.rest_position = rest_position
    self.stiffness = stiffness
    self.damping = damping

func get_next_position(position:Vector3, delta:float = 1.0) -> Vector3:
    velocity = get_next_velocity(velocity, position, delta)
    return position + velocity * delta

func get_next_velocity(velocity:Vector3, position:Vector3, delta:float = 1.0) -> Vector3:
    var acceleration = get_acceleration(velocity, position)
    return velocity + acceleration * delta

func get_acceleration(velocity:Vector3, position:Vector3) -> Vector3:
    var diff = rest_position - position
    var spring_force = diff * stiffness
    var damping_force = -velocity * damping
    return spring_force + damping_force
