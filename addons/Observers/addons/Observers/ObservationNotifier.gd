class_name ObservationNotifier extends Node

signal visible_to(observer: Observer)
signal hidden_to(observer: Observer)
@export var enabled: bool = true
@export_node_path("PhysicsBody3D") var what:NodePath = NodePath("")

@export_group("Occlusion","occlusion_")
@export_flags_3d_physics var occlusion_layer:int = 1:
	set(value):
		occlusion_layer = value
		if _area_3d:
			_area_3d.collision_layer = value
@export_flags_3d_physics var occlusion_mask:int = 1:
	set(value):
		occlusion_mask = value
		if _area_3d:
			_area_3d.collision_mask = value

@export var minimum_visible_time:float = 0.0
@export var minimum_hidden_time:float = 0.0

@onready var _body: PhysicsBody3D = get_node_or_null(what) if not what.is_empty() else get_parent()

var _area_3d: Area3D
var observers: Dictionary[int,Dictionary] = {}

func _initialize() -> void:
	_area_3d = Area3D.new()
	var collision_shape:CollisionShape3D
	for child in _body.get_children():
		if child is CollisionShape3D:
			collision_shape = child.duplicate()
			break
	_area_3d.add_child(collision_shape)
	add_child(_area_3d,true,INTERNAL_MODE_BACK)

func _setup() -> void:
	_area_3d.collision_layer = occlusion_layer
	_area_3d.collision_mask = occlusion_mask
	_area_3d.area_entered.connect(_on_area_entered)
	_area_3d.area_exited.connect(_on_area_exited)
	print("minimum_visible_time:", minimum_visible_time)

func _check_visibility(delta: float) -> void:
	var direct_space_state = _body.get_world_3d().direct_space_state
	var shape = PhysicsServer3D.body_get_shape(_body.get_rid(),0)
	var shape_type = PhysicsServer3D.shape_get_type(shape)
	var shape_data = PhysicsServer3D.shape_get_data(shape)
	var points = _get_shape_aabb(shape_type, shape_data, _body.global_transform)
	var parameters = PhysicsRayQueryParameters3D.new()
	parameters.collide_with_areas = false
	parameters.collide_with_bodies = true
	parameters.collision_mask = occlusion_mask
	for id in observers:
		var observer: Observer = instance_from_id(id)
		if observer:
			var observer_exclusions = observer.exclusions.duplicate()
			parameters.exclude = observer_exclusions
			if not observer.observable_group.is_empty() and not is_in_group(observer.observable_group):
				continue
			parameters.from = observer.global_transform.origin
			var is_seen = false
			for point in points:
				parameters.to = point
				var result = direct_space_state.intersect_ray(parameters)
				if result and result.collider == _body:
					is_seen = true
					observers[id].visible_time += delta
					if (not observers[id].visible) and observers[id].visible_time > minimum_visible_time:
						observers[id].visible = true
						visible_to.emit.call_deferred(observer)
					observers[id].hidden_time = 0
					break
			if not is_seen:
				observers[id].visible_time = 0
				if observers[id].visible:
					if observers[id].hidden_time > minimum_hidden_time:
						observers[id].visible = false
						hidden_to.emit.call_deferred(observer)
				observers[id].hidden_time += delta

func _get_shape_aabb(shape_type:PhysicsServer3D.ShapeType,shape_data:Variant, trans: Transform3D) -> PackedVector3Array:
	var points: PackedVector3Array = PackedVector3Array()
	match shape_type:
		PhysicsServer3D.SHAPE_CONVEX_POLYGON:
			var least_x:float = 1.79769e308
			var least_y:float = 1.79769e308
			var least_z:float = 1.79769e308
			var most_x:float = -1.79769e308
			var most_y:float = -1.79769e308
			var most_z:float = -1.79769e308
			var shape_points = shape_data
			for point in shape_points:
				least_x = min(least_x,point.x)
				least_y = min(least_y,point.y)
				least_z = min(least_z,point.z)
				most_x = max(most_x,point.x)
				most_y = max(most_y,point.y)
				most_z = max(most_z,point.z)
			points.append_array([
				trans.origin * trans.basis,
				trans.origin + trans.basis * Vector3(least_x, least_y, least_z),
				trans.origin + trans.basis * Vector3(most_x, least_y, least_z),
				trans.origin + trans.basis * Vector3(least_x, most_y, least_z),
				trans.origin + trans.basis * Vector3(most_x, most_y, least_z),
				trans.origin + trans.basis * Vector3(least_x, least_y, most_z),
				trans.origin + trans.basis * Vector3(most_x, least_y, most_z),
				trans.origin + trans.basis * Vector3(least_x, most_y, most_z),
				trans.origin + trans.basis * Vector3(most_x, most_y, most_z),
			])
		PhysicsServer3D.SHAPE_BOX:
			var half_size = shape_data
			points.append_array([
				trans.origin * trans.basis,
				trans.origin + trans.basis * Vector3(-half_size.x, -half_size.y, -half_size.z),
				trans.origin + trans.basis * Vector3(half_size.x, -half_size.y, -half_size.z),
				trans.origin + trans.basis * Vector3(half_size.x, half_size.y, -half_size.z),
				trans.origin + trans.basis * Vector3(-half_size.x, half_size.y, -half_size.z),
				trans.origin + trans.basis * Vector3(-half_size.x, -half_size.y, half_size.z),
				trans.origin + trans.basis * Vector3(half_size.x, -half_size.y, half_size.z),
				trans.origin + trans.basis * Vector3(half_size.x, half_size.y, half_size.z),
				trans.origin + trans.basis * Vector3(-half_size.x, half_size.y, half_size.z)
			])
		PhysicsServer3D.SHAPE_SPHERE:
			var radius = shape_data
			points.append_array([
				trans.origin * trans.basis,
				trans.origin + trans.basis * Vector3(-radius, 0, 0),
				trans.origin + trans.basis * Vector3(radius, 0, 0),
				trans.origin + trans.basis * Vector3(0, -radius, 0),
				trans.origin + trans.basis * Vector3(0, radius, 0),
				trans.origin + trans.basis * Vector3(0, 0, -radius),
				trans.origin + trans.basis * Vector3(0, 0, radius)
			])
		PhysicsServer3D.SHAPE_CAPSULE,PhysicsServer3D.SHAPE_CYLINDER:
			var height = shape_data.height * 0.5
			var radius = shape_data.radius
			points.append_array([
				trans.origin * trans.basis,
				trans.origin + trans.basis * Vector3(radius, height, 0),
				trans.origin + trans.basis * Vector3(-radius, height, 0),
				trans.origin + trans.basis * Vector3(0, height, radius),
				trans.origin + trans.basis * Vector3(0, height, -radius),
				trans.origin + trans.basis * Vector3(radius, -height, 0),
				trans.origin + trans.basis * Vector3(-radius, -height, 0),
				trans.origin + trans.basis * Vector3(0, -height, radius),
				trans.origin + trans.basis * Vector3(0, -height, -radius)
			])
		_:
			# For other shapes, we can return an empty array or handle them as needed
			push_error("Unsupported shape type:", shape_type)
			return PackedVector3Array()
	return points


func _on_area_entered(area: Area3D) -> void:
	if not enabled:
		return
	var area_parent = area.get_parent()
	if area_parent is Observer:
		observers[area_parent.get_instance_id()] = {
			"visible": false,
			"visible_time": 0.0,
			"hidden_time": 0.0,
		}

func _on_area_exited(area: Area3D) -> void:
	var area_parent = area.get_parent()
	if area_parent is Observer:
		if observers.has(area_parent.get_instance_id()):
			observers.erase(area_parent.get_instance_id())
			hidden_to.emit.call_deferred(area_parent)

func _notification(what: int) -> void:
	if what == NOTIFICATION_READY:
		_initialize()
		_setup()
		set_physics_process(enabled)  # Enable or disable physics processing based on enabled state
	if what == NOTIFICATION_PHYSICS_PROCESS:
		_check_visibility(get_physics_process_delta_time())
