@tool
extends Node3D

const PsudoCamera = preload("res://addons/thresholds/PsudoCamera.gd")
const THRESHOLD_EDITOR_MATERIAL: StandardMaterial3D = preload("res://addons/thresholds/ThresholdEditorMaterial.tres")

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


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or (not enabled):
		return
	var is_seen = false
	var space_state:PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var parameters = PhysicsRayQueryParameters3D.new()
	parameters.collision_mask = occlusion_mask
	parameters.collide_with_areas = occlusion_by_areas
	parameters.collide_with_bodies = occlusion_by_bodies
	parameters.hit_back_faces = false
	parameters.hit_from_inside = false
	for psudo_camera in psudo_cameras_in_areas:
		var body = psudo_camera.get_parent()
		if not body or body is not PhysicsBody3D:
			continue
		parameters.to = body.global_transform.origin
		var aabb = _get_aabb()
		var nearest_corners = _sort_nearest_corners(aabb, body.global_transform.origin)
		var viewer_facing_me = psudo_camera.aabb_within_frustum(aabb)
		if viewer_facing_me:
			for corner in nearest_corners:
				parameters.from = corner
				var intersection_result = space_state.intersect_ray(parameters)
				if intersection_result.collider == body:
					is_seen = true
					break
	detected = is_seen

func _sort_nearest_corners(aabb: AABB, to: Vector3) -> PackedVector3Array:
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
	corners.sort_custom(func(a, b):
		return a.distance_to(to) < b.distance_to(to))

	return PackedVector3Array(corners)

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
