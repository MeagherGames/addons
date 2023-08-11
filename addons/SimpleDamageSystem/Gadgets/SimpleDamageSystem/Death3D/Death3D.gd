@icon("./death.png")
extends Node
class_name Death3D

signal hit()
signal died()

@export var spawn_at_checkpoint:bool = false
@export var spawn_time:float = 1.0
@export var character:Character

var spawn_point:Vector3

func _ready():
	spawn_point = character.global_position

func on_hit(_data:HitData3D):
	emit_signal("hit")
	character.set_physics_process(false)
	await get_tree().create_timer(spawn_time).timeout
	die()

func die():
	var spawn_location = Game.last_checkpoint if spawn_at_checkpoint else spawn_point
	character.global_position = spawn_location
	character.velocity = Vector3.ZERO
	character.set_physics_process(true)
	emit_signal("died")
