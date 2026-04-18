extends Node

var authority: MultiplayerAuthoritySynchronizer = MultiplayerAuthoritySynchronizer.new()

func _ready() -> void:
	add_child(authority)
	
func start() -> void:
	LanMeshNetwork.start_mesh_discovery()
	
func stop() -> void:
	LanMeshNetwork.stop_mesh_discovery()
