@icon("./hurt_box.png")
extends Area3D
class_name HurtBox3D

signal hit(data:HitData3D)

@export var root_node:Node
@export var damage:float = 1.0
@export var knockback_strength:float = 0.0
@export var knockback_direction:Vector3 = Vector3.ZERO
@export var knockback_relative:bool = false

func _ready():
    area_entered.connect(on_area_entered)

func on_area_entered(area:Area3D):
    if area is HitBox3D:
        var data:HitData3D = HitData3D.new()
        data.source = self
        data.source_root_node = root_node
        data.source_position = global_position
        data.damage = damage
        data.knockback_strength = knockback_strength
        if knockback_relative:
            data.knockback_direction = global_transform.basis * knockback_direction
        else:
            data.knockback_direction = knockback_direction
        area.trigger_hit(data) # adds target data to hit data
        emit_signal("hit", data)