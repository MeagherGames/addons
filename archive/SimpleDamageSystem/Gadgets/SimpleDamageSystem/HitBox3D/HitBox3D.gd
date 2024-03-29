@icon("./hit_box.png")
extends Area3D
class_name HitBox3D

signal hit(data:HitData3D)

@export var root_node:Node

func trigger_hit(data:HitData3D):
	data.target = self
	data.target_root_node = root_node
	data.target_position = global_position
	emit_signal("hit", data)