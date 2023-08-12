extends RefCounted
class_name HitData3D

var source:HurtBox3D
var source_position:Vector3
var source_root_node:Node
var target:HitBox3D
var target_position:Vector3
var target_root_node:Node

var damage:float
var knockback_strength:float
var knockback_direction:Vector3

func get_knockback() -> Vector3:
    if knockback_direction.is_zero_approx():
        return (target_position - source_position).normalized() * knockback_strength
    return knockback_direction.normalized() * knockback_strength