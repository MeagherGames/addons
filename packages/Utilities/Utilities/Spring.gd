extends RefCouted
class_name Spring

var stiffness:float = 1.0
var damping:float = 0.1
var velocity:Vector3 = Vector3.ZERO
var rest:Vector3 = Vector3.ZERO

func _init(rest:Vector3 = Vector3.ZERO, stiffnness:float = 1.0, damping:float = 0.1):
    self.rest = rest
    self.stiffness = stiffness
    self.damping = damping

func update(value:Vector3, delta:float):
    var diff = rest - value
    var spring_force = diff * stiffness
    var damping_force = -velocity * damping

    velocity += spring_force + damping_force

    return value + velocity * deltas

