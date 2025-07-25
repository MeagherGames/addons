@tool
class_name Portal3D extends MeshInstance3D

signal body_entered(body: Node3D)
signal body_exited(body: Node3D)

const PORTAL_MESH = preload("res://addons/portals/assets/portal_3d_mesh.tres")
const PORTAL_MATERIAL = preload("res://addons/portals/assets/portal_3d_material.tres")
const PORTAL_COLLISION_SHAPE = preload("res://addons/portals/assets/portal_3d_collision_shape.tres")

@export_node_path("Marker3D") var teleport_target_path: NodePath:
	set(value):
		teleport_target_path = value
		update_configuration_warnings()
@export var portal_size: Vector2 = Vector2(2, 2):
	set(value):
		portal_size = value
		if is_node_ready():
			if mesh:
				mesh.size = value
				var col_shape: BoxShape3D = collision_shape.shape as BoxShape3D
				col_shape.size = Vector3(value.x, value.y, 0.1)  # Thin box for portal
@export var max_distance: float = 10.0
@export var disable_teleport:bool = false

@onready var teleport_target: Marker3D = get_node_or_null(teleport_target_path)

var sub_viewport: SubViewport
var portal_camera: Camera3D
var area_3d: Area3D
var collision_shape: CollisionShape3D


var active_camera: Camera3D
var portal_visible: bool = true
var portal_disabled: bool = false
var bodies_in_portal: Array[Node3D] = []



@export_flags_3d_physics var teleport_layer: int = 1:
	set(value):
		teleport_layer = value
		if area_3d:
			area_3d.collision_layer = value

func _ready() -> void:
	#await get_tree().root.ready
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_setup_sub_viewport()
	_setup_material()
	_setup_mesh()
	_setup_area_3d()
	_setup_collision_shape()
	if not Engine.is_editor_hint():
		active_camera = get_viewport().get_camera_3d()
		_setup_signals()

	


func _setup_sub_viewport() -> void:
	sub_viewport = SubViewport.new()
	sub_viewport.name = "SubViewport"
	sub_viewport.size = Vector2(512, 512)
	sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	portal_camera = Camera3D.new()
	portal_camera.name = "Camera3D"
	sub_viewport.add_child(portal_camera,true,INTERNAL_MODE_FRONT)
	add_child(sub_viewport,true,INTERNAL_MODE_BACK)

func _setup_mesh() -> void:
	mesh = PORTAL_MESH.duplicate()

func _setup_material() -> void:
	var material = PORTAL_MATERIAL.duplicate()
	material.albedo_texture = sub_viewport.get_texture()
	# Assign the material to the mesh
	material_override = material

func _setup_area_3d() -> void:
	area_3d = Area3D.new()
	area_3d.name = "Area3D"
	add_child(area_3d, true, INTERNAL_MODE_FRONT)

func _setup_collision_shape() -> void:
	collision_shape = CollisionShape3D.new()
	collision_shape.name = "CollisionShape3D"
	var shape = PORTAL_COLLISION_SHAPE.duplicate()
	collision_shape.shape = shape
	area_3d.add_child(collision_shape, true, INTERNAL_MODE_FRONT)


func _setup_signals() -> void:
	# Connect signals for area 3D
	area_3d.body_entered.connect(_on_area_3d_body_entered)
	area_3d.body_exited.connect(_on_area_3d_body_exited)

func _main_camera_distance_to_portal() -> float:
	if not active_camera:
		return 0.0
	return active_camera.global_transform.origin.distance_to(global_transform.origin)

func _update_portal_camera() -> void:
	# Skip camera updates in editor
	if Engine.is_editor_hint():
		return
	
	if not active_camera or not portal_camera or not teleport_target:
		return
	var main_viewport = get_viewport()
	# Calculate the relative position of the main camera to this portal
	var camera_to_portal = active_camera.global_transform.origin - global_transform.origin
	var camera_local_pos = global_transform.basis.inverse() * camera_to_portal
	
	# Transform to target space using the same simple approach as teleportation
	var portal_to_target_rotation = teleport_target.global_transform.basis * global_transform.basis.inverse()
	var target_space_offset = portal_to_target_rotation * camera_local_pos
	
	# Position the portal camera relative to the teleport target (unbound)
	portal_camera.global_transform.origin = teleport_target.global_transform.origin + target_space_offset
	
	# Handle rotation the same way - transform camera's basis through portal rotation
	var camera_basis_portal_space = global_transform.basis.inverse() * active_camera.global_transform.basis
	portal_camera.global_transform.basis = teleport_target.global_transform.basis * camera_basis_portal_space
	
	# Adjust FOV based on aspect ratio difference and distance to portal
	var main_aspect = float(main_viewport.size.x) / float(main_viewport.size.y)
	var portal_aspect = portal_size.x / portal_size.y
	
	# Calculate base adjusted FOV for aspect ratio
	var base_fov = active_camera.fov
	var aspect_adjusted_fov = base_fov
	
	if portal_aspect != main_aspect:
		# Convert FOV to horizontal FOV, adjust for aspect ratio, then convert back
		var h_fov = rad_to_deg(2.0 * atan(tan(deg_to_rad(base_fov) * 0.5) * main_aspect))
		aspect_adjusted_fov = rad_to_deg(2.0 * atan(tan(deg_to_rad(h_fov) * 0.5) / portal_aspect))
	
	# Blend between aspect-adjusted FOV (far) and main camera FOV (near)
	var distance_factor = clamp(_main_camera_distance_to_portal() / max_distance, 0.0, 1.0)
	portal_camera.fov = lerp(base_fov, aspect_adjusted_fov, distance_factor)
	
	# Set dynamic near plane behind the teleport target to prevent clipping
	var target_to_camera = portal_camera.global_transform.origin - teleport_target.global_transform.origin
	var distance_to_target = target_to_camera.length()
	var near_offset = 0.25  # Distance behind the target
	portal_camera.near = max(0.01, distance_to_target - near_offset)
	
	# Set far plane to maintain the same depth range as main camera
	var main_depth_range = active_camera.far - active_camera.near
	portal_camera.far = portal_camera.near + main_depth_range

func _should_portal_be_visible() -> bool:
	if not active_camera:
		return false
	
	# Check if camera is looking at the front of the portal
	var camera_to_portal = global_transform.origin - active_camera.global_transform.origin
	var portal_forward = -global_transform.basis.z
	var is_front_facing = camera_to_portal.dot(portal_forward) > 0.0
	
	if not is_front_facing:
		return false
	
	# Basic frustum culling - check if portal is roughly in camera view
	var camera_forward = -active_camera.global_transform.basis.z
	var camera_to_portal_normalized = camera_to_portal.normalized()
	var dot_product = camera_forward.dot(camera_to_portal_normalized)
	
	# If dot product is positive and reasonably large, portal is in view
	# Using a threshold of about 60 degrees (cos(60°) ≈ 0.5)
	return dot_product > 0.3

func _update_portal_visibility() -> void:
	# Skip visibility updates in editor
	if Engine.is_editor_hint():
		return
		
	var should_be_visible = _should_portal_be_visible()
	
	if portal_visible != should_be_visible:
		portal_visible = should_be_visible
		visible = portal_visible
		
		# Also disable/enable the sub viewport to save performance
		if sub_viewport:
			sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if portal_visible else SubViewport.UPDATE_DISABLED

func _scale_sub_viewport_resolution() -> void:
	# Skip resolution scaling in editor
	if Engine.is_editor_hint():
		return
		
	var distance: float = _main_camera_distance_to_portal()
	# Consider inverting the scale factor for more intuitive distance scaling
	if distance <= 0.0:
		distance = 0.1  # Prevent division by zero or negative distance
	# Scale factor is inversely proportional to distance, clamped between 0.1 and 1.0
	var scale_factor: float = lerp(1.0, 0.1, distance / max_distance)
	scale_factor = clamp(scale_factor, 0.1, 1.0)
	
	# Calculate SubViewport size based on portal aspect ratio and distance scaling
	var portal_aspect = portal_size.x / portal_size.y
	var base_height = int(512 * scale_factor)  # Scale the base resolution
	var calculated_width = int(base_height * portal_aspect)
	
	# Ensure minimum dimensions
	calculated_width = max(calculated_width, 64)
	base_height = max(base_height, 64)
	
	sub_viewport.size = Vector2i(calculated_width, base_height)

func _process(_delta: float) -> void:
	# Skip processing in editor
	if Engine.is_editor_hint():
		return

	_update_portal_visibility()
	if portal_visible:
		_scale_sub_viewport_resolution()
		_update_portal_camera()

func _is_body_on_front_side(body: Node3D) -> bool:
	# Calculate the vector from portal to body
	var portal_to_body = body.global_transform.origin - global_transform.origin
	# Get the portal's forward direction (negative Z in local space)
	var portal_forward = -global_transform.basis.z
	# Check if the body is on the front side (positive dot product)
	return portal_to_body.dot(portal_forward) < 0.0

func _on_area_3d_body_entered(body:Node3D) -> void:
	# Skip teleportation in editor
	if Engine.is_editor_hint():
		return
		
	if not teleport_target:
		return
	
	# Add body to tracking list
	if not bodies_in_portal.has(body):
		bodies_in_portal.append(body)
	
	# Check if body is entering from the back side
	if not _is_body_on_front_side(body):
		portal_disabled = true
		return
	
	# Only teleport if portal is enabled and body is on front side
	if not portal_disabled and not disable_teleport:
		
		# Calculate the relative position of the body to this portal
		var body_to_portal = body.global_transform.origin - global_transform.origin
		var body_to_portal_local = global_transform.basis.inverse() * body_to_portal

		# Transform to target space using the same approach as the camera
		var portal_to_target_rotation = teleport_target.global_transform.basis * global_transform.basis.inverse()
		var target_space_offset = portal_to_target_rotation * body_to_portal_local

		# Calculate the body's distance from the main camera's near plane
		var main_camera_forward = -active_camera.global_transform.basis.z
		var body_to_main_camera = body.global_transform.origin - active_camera.global_transform.origin
		var distance_from_main_near = body_to_main_camera.dot(main_camera_forward) - active_camera.near

		# Apply the basic teleport position first
		var basic_teleport_pos = teleport_target.global_transform.origin + target_space_offset
		
		# Adjust the position to maintain the same distance from the portal camera's near plane
		var portal_camera_forward = -portal_camera.global_transform.basis.z
		var near_offset = 0.25  # Same offset used in portal camera positioning
		var near_plane_position = portal_camera.global_transform.origin + (portal_camera_forward * portal_camera.near)
		var desired_position = near_plane_position + (portal_camera_forward * (distance_from_main_near + near_offset))
		
		# Use the lateral position from basic teleport but depth from near plane calculation
		var lateral_offset = basic_teleport_pos - (portal_camera.global_transform.origin + (portal_camera_forward * portal_camera.near))
		lateral_offset = lateral_offset - (lateral_offset.dot(portal_camera_forward) * portal_camera_forward)  # Remove depth component
		
		# Teleport the body to maintain consistent depth from near plane
		body.global_transform.origin = desired_position + lateral_offset
		
		# Also handle rotation - transform body's basis through portal rotation
		body.global_transform.basis = portal_to_target_rotation * body.global_transform.basis
	body_entered.emit(body)  # Emit signal for body entry

func _on_area_3d_body_exited(body:Node3D) -> void:
	# Skip body tracking in editor
	if Engine.is_editor_hint():
		return
		
	# Remove body from tracking list
	if bodies_in_portal.has(body):
		bodies_in_portal.erase(body)
	
	# Reset portal when all bodies have exited
	if bodies_in_portal.is_empty():
		portal_disabled = false
	body_exited.emit(body)  # Emit signal for body exit

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if teleport_target_path.is_empty() or teleport_target_path == null:
		warnings.append("Portal3D is missing a teleport target. Please set the teleport_target_path property.")
	return warnings
