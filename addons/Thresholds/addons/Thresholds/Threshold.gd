@tool
extends Node3D

const PsudoCamera = preload("res://addons/Thresholds/PsudoCamera.gd")
const THRESHOLD_EDITOR_MATERIAL: StandardMaterial3D = preload("res://addons/Thresholds/ThresholdEditorMaterial.tres")

signal detection_changed(detected: bool)

@export var enabled: bool = true
@export var shape: BoxShape3D = BoxShape3D.new():
	set(value):
		shape = value
		_shape_points = shape.get_debug_mesh().get_faces()

@export var entrance_area: Area3D
@export var exit_area: Area3D

@export_group("Occlusion","occlusion_")
@export var occlusion_by_bodies: bool = true
@export var occlusion_by_areas: bool = false
@export_flags_3d_physics var occlusion_mask: int = 1

@export_group("Debug","debug_")
@export var debug_color: Color = Color(0, 1, 0):
	set(value):
		debug_color = value
		if Engine.is_editor_hint():
			var mesh_instance: MeshInstance3D = get_child(0,true)
			if mesh_instance:
				mesh_instance.material_override.albedo_color = Color(debug_color.r, debug_color.g, debug_color.b, THRESHOLD_EDITOR_MATERIAL.albedo_color.a) # Semi-transparent
@export var debug_show_shape: bool = true

var detected: bool = false:
	set(value):
		if Engine.is_editor_hint():
			return
		if detected == value:
			return
		detected = value
		detection_changed.emit(detected)

var psudo_cameras_in_areas: Array[PsudoCamera] = []
var _shape_points: PackedVector3Array

var _threads: Array[Thread] = []
var mutex: Mutex = Mutex.new()
var semaphore: Semaphore = Semaphore.new()
var exiting: bool = false
var physics_queries: Array[Dictionary] = []

func _get_aabb() -> AABB:
	var aabb:AABB = AABB()
	if not shape:
		return aabb
	aabb.size = shape.size * 2.0
	aabb.position = (-shape.size * 0.5) + global_transform.origin
	aabb.position = global_transform.basis * aabb.position
	return aabb

func _ready() -> void:
	if not Engine.is_editor_hint():
		entrance_area.body_entered.connect(_on_entered.bind(entrance_area))
		entrance_area.body_exited.connect(_on_exited.bind(entrance_area))
		exit_area.body_entered.connect(_on_entered.bind(exit_area))
		exit_area.body_exited.connect(_on_exited.bind(exit_area))
		if debug_show_shape:
			var array_mesh = shape.get_debug_mesh()
			var mesh_instance: MeshInstance3D = MeshInstance3D.new()
			mesh_instance.mesh = array_mesh
			mesh_instance.material_override = THRESHOLD_EDITOR_MATERIAL
			mesh_instance.material_override.albedo_color = Color(debug_color.r, debug_color.g, debug_color.b, THRESHOLD_EDITOR_MATERIAL.albedo_color.a) # Semi-transparent
			add_child(mesh_instance, false, INTERNAL_MODE_BACK)
			detection_changed.connect(func(detected: bool):
				print("Detection changed: ", detected)
				if detected:
					var inverted_color = debug_color.inverted()
					mesh_instance.material_override.albedo_color = Color(inverted_color.r, inverted_color.g, inverted_color.b, THRESHOLD_EDITOR_MATERIAL.albedo_color.a) # Semi-transparent
				else:
					mesh_instance.material_override.albedo_color = Color(debug_color.r, debug_color.g, debug_color.b, THRESHOLD_EDITOR_MATERIAL.albedo_color.a) # Semi-transparent
			)
	else:
		var array_mesh = shape.get_debug_mesh()
		var mesh_instance: MeshInstance3D = MeshInstance3D.new()
		mesh_instance.mesh = array_mesh
		mesh_instance.material_override = THRESHOLD_EDITOR_MATERIAL
		mesh_instance.material_override.albedo_color = Color(debug_color.r, debug_color.g, debug_color.b, THRESHOLD_EDITOR_MATERIAL.albedo_color.a) # Semi-transparent
		add_child(mesh_instance, false, INTERNAL_MODE_BACK)


func _get_corners(aabb: AABB, sort_fn = null) -> PackedVector3Array:
	var corners: Array = [
		aabb.position + Vector3(aabb.size.x, aabb.size.y, aabb.size.z) * 0.5,
		aabb.position + Vector3(aabb.size.x, aabb.size.y, -aabb.size.z) * 0.5,
		aabb.position + Vector3(aabb.size.x, -aabb.size.y, aabb.size.z) * 0.5,
		aabb.position + Vector3(aabb.size.x, -aabb.size.y, -aabb.size.z) * 0.5,
		aabb.position + Vector3(-aabb.size.x, aabb.size.y, aabb.size.z) * 0.5,
		aabb.position + Vector3(-aabb.size.x, aabb.size.y, -aabb.size.z) * 0.5,
		aabb.position + Vector3(-aabb.size.x, -aabb.size.y, aabb.size.z) * 0.5,
		aabb.position + Vector3(-aabb.size.x, -aabb.size.y, -aabb.size.z) * 0.5
	]
	if sort_fn:
		corners.sort_custom(sort_fn)
	return PackedVector3Array(corners)

func _get_cube_faces(corners: PackedVector3Array) -> Array[PackedVector3Array]:
	var faces: Array[PackedVector3Array] = []
	
	# Each face is defined by 4 corners, split into 2 triangles
	# Front face: corners[0,1,2,3]
	faces.append(PackedVector3Array([corners[0], corners[1], corners[2]]))
	faces.append(PackedVector3Array([corners[1], corners[3], corners[2]]))
	
	# Back face: corners[4,5,6,7]
	faces.append(PackedVector3Array([corners[4], corners[6], corners[5]]))
	faces.append(PackedVector3Array([corners[5], corners[6], corners[7]]))
	
	# Left face: corners[0,2,4,6]
	faces.append(PackedVector3Array([corners[0], corners[2], corners[4]]))
	faces.append(PackedVector3Array([corners[2], corners[6], corners[4]]))
	
	# Right face: corners[1,3,5,7]
	faces.append(PackedVector3Array([corners[1], corners[5], corners[3]]))
	faces.append(PackedVector3Array([corners[3], corners[5], corners[7]]))
	
	# Top face: corners[0,1,4,5]
	faces.append(PackedVector3Array([corners[0], corners[4], corners[1]]))
	faces.append(PackedVector3Array([corners[1], corners[4], corners[5]]))
	
	# Bottom face: corners[2,3,6,7]
	faces.append(PackedVector3Array([corners[2], corners[3], corners[6]]))
	faces.append(PackedVector3Array([corners[3], corners[7], corners[6]]))
	
	return faces

func _ray_to_triangle(occluding_triangle: PackedVector3Array, from: Vector3, to: Vector3) -> bool:
	var ray_direction = (to - from).normalized()
	var ray_vector = to - from
	
	# Check if ray intersects the plane
	var plane_normal = (occluding_triangle[1] - occluding_triangle[0]).cross(occluding_triangle[2] - occluding_triangle[0]).normalized()
	var plane_point = occluding_triangle[0]
	var d = -plane_point.dot(plane_normal)
	
	var ray_dot_normal = plane_normal.dot(ray_direction)
	if abs(ray_dot_normal) < 1e-6:  # Ray is parallel to plane
		return false
	
	var t = -(plane_normal.dot(from) + d) / ray_dot_normal
	if t < 0 or t > ray_vector.length():
		return false
	
	var intersection_point = from + ray_direction * t
	
	# Check if intersection point is inside the triangle
	var u = occluding_triangle[1] - occluding_triangle[0]
	var v = occluding_triangle[2] - occluding_triangle[0]
	var w = intersection_point - occluding_triangle[0]
	var uu = u.dot(u)
	var uv = u.dot(v)
	var vv = v.dot(v)
	var wu = w.dot(u)
	var wv = w.dot(v)
	var denominator = uv * uv - uu * vv
	if abs(denominator) < 1e-6:
		return false
	var s = (uv * wv - vv * wu) / denominator
	var tt = (uv * wu - uu * wv) / denominator
	return s >= 0 and tt >= 0 and s + tt <= 1

func _is_threshold_visible(psudo_camera: PsudoCamera, body: PhysicsBody3D):
	while true:
		semaphore.wait()
		mutex.lock()
		var exit = exiting
		mutex.unlock()
		if exit:
			return
		if not psudo_camera:
			return
		var aabb: AABB = _get_aabb()
		if not psudo_camera.aabb_within_frustum(aabb):
			continue
		var corners = _get_corners(_get_aabb())
		if corners.is_empty():
			continue
		var occluding_triangles: Array[PackedVector3Array] = _get_cube_faces(corners)
		var visible_corners: PackedVector3Array = PackedVector3Array()
		for corner in corners:
			var blocked = false
			for occluding_triangle in occluding_triangles:
				if occluding_triangle.has(corner):
					continue
				if _ray_to_triangle(occluding_triangle, corner, psudo_camera.global_transform.origin):
					blocked = true
					break
			if not blocked and not visible_corners.has(corner):
				visible_corners.append(corner)
		var parameters = PhysicsRayQueryParameters3D.new()
		parameters.collision_mask = occlusion_mask
		parameters.collide_with_areas = occlusion_by_areas
		parameters.collide_with_bodies = occlusion_by_bodies
		parameters.hit_back_faces = false
		parameters.hit_from_inside = false
		parameters.to = body.global_transform.origin
		for corner in visible_corners:
			parameters.from = corner
			mutex.lock()
			physics_queries.append({
				"body_id": body.get_instance_id(),
				"parameters": parameters
			})
			mutex.unlock()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or (not enabled) or psudo_cameras_in_areas.is_empty():
		return
	var current_detection: bool = false
	var physics_space_state = get_world_3d().direct_space_state
	for thread in _threads:
		semaphore.post()
	await get_tree().physics_frame
	mutex.lock()
	var pending_queries = physics_queries.duplicate()
	physics_queries.clear()
	mutex.unlock()
	for query in pending_queries:
		var result = physics_space_state.intersect_ray(query.parameters)
		if result and result.collider_id == query.body_id:
			current_detection = true
			break
	detected = current_detection

func _on_entered(body:PhysicsBody3D, detection_area: Area3D) -> void:
	if enabled:
		var psudo_camera:PsudoCamera = null
		for child in body.get_children():
			if child is PsudoCamera:
				psudo_camera = child
				break
		if not psudo_camera:
			return
		psudo_cameras_in_areas.append(psudo_camera)
		if psudo_cameras_in_areas.size() > _threads.size():
			# If we have more psudo_cameras than threads, we need to add a new thread
			_threads.append(Thread.new())
		var index = _threads.size() - 1
		if not _threads[index].is_started():
			_threads[index].start(_is_threshold_visible.bind(psudo_camera, psudo_camera.get_parent()))


func _on_exited(body:PhysicsBody3D, detection_area: Area3D) -> void:
	if enabled:
		var psudo_camera:PsudoCamera = null
		for child in body.get_children():
			if child is PsudoCamera:
				psudo_camera = child
				break
		if not psudo_camera:
			return
		var index = psudo_cameras_in_areas.find(psudo_camera)
		if index != -1:
			psudo_cameras_in_areas.remove_at(index)
		if index < _threads.size():
			_threads[index].wait_to_finish()
			_threads.remove_at(index)


func _exit_tree() -> void:
	for thread in _threads:
		if thread.is_started():
			thread.wait_to_finish()
	_threads.clear()
	psudo_cameras_in_areas.clear()
