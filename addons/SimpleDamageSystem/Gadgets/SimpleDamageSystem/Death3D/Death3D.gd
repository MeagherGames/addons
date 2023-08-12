@icon("./death.png")
extends Node
class_name Death3D

signal hit()
signal healed()
signal killed()
signal respawned()

@export var max_health:float = 1.0
@export var spawn_at_checkpoint:bool = false
@export var spawn_time:float = 1.0
@export var character:CharacterBody3D
@export var velocity_control:CharacterVelocityControl3D

var health:float = max_health
var spawn_point:Vector3

func _ready():
	spawn_point = character.global_position

func on_hit(data:HitData3D):
	if data.damage > 0:
		emit_signal("hit")
	elif data.damage < 0:
		emit_signal("healed")
		
	health = max(health-data.damage, 0.0)
	if health <= 0:
		kill()
	else:
		# knockback
		var knockback = data.get_knockback()
		velocity_control.velocity = knockback
	
func kill():
	emit_signal("killed")
	await get_tree().create_timer(spawn_time).timeout
	respawn()

func respawn():
	var spawn_location = Game.last_checkpoint if spawn_at_checkpoint else spawn_point
	character.global_position = spawn_location
	emit_signal("respawned")
