class_name Observer extends Node3D

enum OCCLUSION_MODE{
	ANY_POINT = 0, # Any point must be visible for body to be considered visible
	#ALL_POINTS = 1, # All points must be visible for body to be considered visible
	ORIGIN = 2, # The origin of the body must be visible for it to be considered visible
	RANDOM = 3, # A random point within the body must be visible for it to be considered visible
}

signal body_visible(body: PhysicsBody3D)
signal body_hidden(body: PhysicsBody3D)

@export var frustum_shape: FrustumShape = FrustumShape.new()
@export var observable_group: String = "" # Group to which this observer belongs
@export var real_camera: Camera3D
@export var enabled: bool = true: # Whether this camera can be monitored:
	set(value):
		if enabled == value:
			return
		if _area_3d:
			_area_3d.monitorable = value
		enabled = value
@export_group("Occlusion", "occlusion_")
@export var occlusion_mode:OCCLUSION_MODE = OCCLUSION_MODE.ANY_POINT
@export var occlusion_exclude_parent: bool = true
@export var occlusion_check_frequency: int = 1 # How often to check for occlusion
@export_node_path("PhysicsBody3D") var occlusion_exclusions: Array[NodePath] = [] # Nodes to exclude from occlusion checks
var exclusions: Array[RID] = []# RIDs of excluded nodes for occlusion checks
@export_flags_3d_physics var occlusion_mask:int = 1: # The occlusion mask for the camera
	set(value):
		occlusion_mask = value
		if _area_3d:
			_area_3d.collision_layer = value
			_area_3d.collision_mask = value
@export_group("Multiplayer", "multiplayer_")
@export var multiplayer_client_can_set_camera: bool = true

var _area_3d:Area3D = Area3D.new()
var _collision_shape:CollisionShape3D = CollisionShape3D.new()
var occlusion_check_counter: int = 0

func _setup() -> void:
	if real_camera and (not multiplayer.is_server() or multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		# calculate FOV based on parent camera and viewport size
		var viewport = get_viewport()
		if not viewport:
			return
		global_transform.origin = real_camera.global_transform.origin
		global_transform.basis = real_camera.global_transform.basis
		frustum_shape.view_size = Vector2(viewport.size)
		frustum_shape.fov = real_camera.fov # Use the camera's FOV
		frustum_shape.far = real_camera.far
		frustum_shape.near = real_camera.near
		if multiplayer_client_can_set_camera and not multiplayer.is_server():
			# Update the server with the camera parameters
			_update_server_camera.rpc_id(1, frustum_shape)
	_collision_shape.shape = frustum_shape
	_area_3d.add_child(_collision_shape)
	_area_3d.name = "FrustumArea"
	_area_3d.monitorable = enabled
	_area_3d.collision_layer = occlusion_mask
	_area_3d.collision_mask = occlusion_mask
	add_child(_area_3d,true)
	if occlusion_exclude_parent and get_parent() is PhysicsBody3D:
		exclusions.append(get_parent().get_rid())
	for exclusion in occlusion_exclusions:
		var node = get_node_or_null(exclusion)
		if node:
			exclusions.append(node.get_rid())

@rpc("any_peer","call_remote","reliable")
func _update_server_camera(data:FrustumShape) -> void:
	if not multiplayer.is_server() or not multiplayer_client_can_set_camera:
		return
	frustum_shape.view_size = data.view_size
	frustum_shape.fov = data.fov
	frustum_shape.far = data.far
	frustum_shape.near = data.near


func _notification(what: int) -> void:
	if what == NOTIFICATION_READY:
		_setup()

func _notified_visible(body: PhysicsBody3D) -> void:
	pass

func _notified_hidden(body: PhysicsBody3D) -> void:
	pass

func notified_visible(body: PhysicsBody3D) -> void:
	if not enabled:
		return
	_notified_visible(body)
	body_visible.emit(body)

func notified_hidden(body: PhysicsBody3D) -> void:
	if not enabled:
		return
	_notified_hidden(body)
	body_hidden.emit(body)