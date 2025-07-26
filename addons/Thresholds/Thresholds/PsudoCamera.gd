extends Node3D
@export var view_size:Vector2 = Vector2(800, 600) # Size of the viewport for the viewer
@export var fov:float = 75.0 # Vertical field of view in degrees
@export var far:float = 1000.0 # Far clipping distance
@export var near:float = 0.1 # Near clipping distance
@export var real_camera: Camera3D
var vfov:float
var hfov:float

func _ready() -> void:
	if real_camera:
		# calculate FOV based on parent camera and viewport size
		var viewport = get_viewport()
		if not viewport:
			return
		var viewport_size = viewport.size
		var aspect_ratio = float(viewport_size.x) / float(viewport_size.y)
		vfov = real_camera.fov  # Camera FOV is vertical in Godot
		hfov = 2.0 * rad_to_deg(atan(tan(deg_to_rad(vfov / 2.0)) * aspect_ratio))
		far = real_camera.far
		near = real_camera.near
	else:
		var aspect_ratio = view_size.x / view_size.y
		vfov = fov  # Use the exported vertical FOV
		hfov = 2.0 * rad_to_deg(atan(tan(deg_to_rad(vfov / 2.0)) * aspect_ratio))

func point_within_frustum(point: Vector3) -> bool:
	var to_point = global_transform.origin - point
	var local_to_point = global_transform.basis.inverse() * to_point
	var distance = local_to_point.z
	if distance < near or distance > far:
		return false
	
	var half_width = tan(deg_to_rad(hfov / 2)) * distance
	var half_height = tan(deg_to_rad(vfov / 2)) * distance

	if abs(local_to_point.x) > half_width or abs(local_to_point.y) > half_height:
		return false
	return true

func aabb_within_frustum(aabb: AABB) -> bool:
	var corners: PackedVector3Array = [
		aabb.position + Vector3(aabb.size.x, aabb.size.y, aabb.size.z) * 0.5,
		aabb.position + Vector3(aabb.size.x, aabb.size.y, -aabb.size.z) * 0.5,
		aabb.position + Vector3(aabb.size.x, -aabb.size.y, aabb.size.z) * 0.5,
		aabb.position + Vector3(aabb.size.x, -aabb.size.y, -aabb.size.z) * 0.5,
		aabb.position + Vector3(-aabb.size.x, aabb.size.y, aabb.size.z) * 0.5,
		aabb.position + Vector3(-aabb.size.x, aabb.size.y, -aabb.size.z) * 0.5,
		aabb.position + Vector3(-aabb.size.x, -aabb.size.y, aabb.size.z) * 0.5,
		aabb.position + Vector3(-aabb.size.x, -aabb.size.y, -aabb.size.z) * 0.5
	]
	for corner in corners:
		if point_within_frustum(corner):
			return true
	return false