@icon("./hurt_box.png")
extends Area3D
class_name HurtBox3D

signal hit(data:HitData3D)

@export var root_node:Node

func _ready():
    area_entered.connect(on_area_entered)

func on_area_entered(area:Area3D):
    if area is HitBox3D:
        var data:HitData3D = HitData3D.new()
        data.source = self
        data.source_root_node = root_node
        data.source_position = global_position
        area.trigger_hit(data) # adds target data to hit data
        emit_signal("hit", data)