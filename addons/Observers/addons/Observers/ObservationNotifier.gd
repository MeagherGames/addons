class_name ObservationNotifier extends Node3D

enum OBSERVER_NOTIFIER_MODE{
	OCCLUSION = 1, # Observers when body enters the area
	OBSERVATION = 2 # Observers when body is not occluded
}

signal visible_to(observer: Observer)
signal hidden_to(observer: Observer)
@export var enabled: bool = true:
	set(value):
		if enabled == value:
			return
		set_physics_process(value)
		if _area_3d:
			_area_3d.monitorable = value
			if enabled and not value:
				observers.clear()
			elif value and not enabled:
				var areas = _area_3d.get_overlapping_areas()
				for area in areas:
					_on_area_entered(area)
		enabled = value
@export var mode: OBSERVER_NOTIFIER_MODE = OBSERVER_NOTIFIER_MODE.OCCLUSION
@export_node_path("PhysicsBody3D") var what:NodePath = NodePath("")
@export_group("Occlusion","occlusion_")
@export var occlusion_check_frequency:int = 1: # How often to check visibility in physics process
	set(value):
		occlusion_check_frequency = value
		local_time_scale = float(occlusion_check_frequency)
@export_flags_3d_physics var occlusion_layer:int = 1:
	set(value):
		occlusion_layer = value
		if _area_3d:
			_area_3d.collision_layer = value
			_area_3d.collision_mask = value

@export var minimum_visible_time:float = 0.0
@export var minimum_hidden_time:float = 0.0

@onready var _body: PhysicsBody3D = get_node_or_null(what) if not what.is_empty() else get_parent()

var _area_3d: Area3D
var observers: Dictionary[int,Dictionary] = {}
var check_counter:int = 0
var local_time_scale: float = 1.0

func _initialize() -> void:
	local_time_scale = float(occlusion_check_frequency)
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
	_area_3d.collision_mask = occlusion_layer
	_area_3d.area_entered.connect(_on_area_entered)
	_area_3d.area_exited.connect(_on_area_exited)
	print("minimum_visible_time:", minimum_visible_time)

func _check_visibility(delta: float) -> void:
	var direct_space_state = _body.get_world_3d().direct_space_state
	var shape = PhysicsServer3D.body_get_shape(_body.get_rid(),0)
	var shape_type = PhysicsServer3D.shape_get_type(shape)
	var shape_data = PhysicsServer3D.shape_get_data(shape)
	var parameters = PhysicsRayQueryParameters3D.new()
	parameters.collide_with_areas = false
	parameters.collide_with_bodies = true
	parameters.collision_mask = occlusion_layer
	var points = _get_shape_aabb(shape_type, shape_data, _body.global_transform)
	for id in observers:
		var observer: Observer = instance_from_id(id)
		if observer:
			var observer_exclusions = observer.exclusions.duplicate()
			parameters.exclude = observer_exclusions
			if not observer.observable_group.is_empty() and not is_in_group(observer.observable_group):
				continue
			observer.occlusion_check_counter += 1
			if observer.occlusion_check_counter < observer.occlusion_check_frequency:
				continue
			observer.occlusion_check_counter = 0
			parameters.from = observer.global_transform.origin
			match observer.occlusion_mode:
				Observer.OCCLUSION_MODE.ANY_POINT:
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
								observer.notified_visible(_body)
							observers[id].hidden_time = 0
							break
					if not is_seen:
						observers[id].visible_time = 0
						if observers[id].visible:
							if observers[id].hidden_time > minimum_hidden_time:
								observers[id].visible = false
								hidden_to.emit.call_deferred(observer)
								observer.notified_hidden(_body)
						observers[id].hidden_time += delta
				Observer.OCCLUSION_MODE.ORIGIN:
					parameters.to = _body.global_transform.origin
					var result = direct_space_state.intersect_ray(parameters)
					if result and result.collider == _body:
						observers[id].visible_time += delta
						if (not observers[id].visible) and observers[id].visible_time > minimum_visible_time:
							observers[id].visible = true
							visible_to.emit.call_deferred(observer)
							observer.notified_visible(_body)
						observers[id].hidden_time = 0
					else:
						observers[id].visible_time = 0
						if observers[id].visible:
							if observers[id].hidden_time > minimum_hidden_time:
								observers[id].visible = false
								hidden_to.emit.call_deferred(observer)
								observer.notified_hidden(_body)
						observers[id].hidden_time += delta
				Observer.OCCLUSION_MODE.RANDOM:
					var random_point = _random_point_within_points(points)
					parameters.to = random_point
					var result = direct_space_state.intersect_ray(parameters)
					if result and result.collider == _body:
						observers[id].visible_time += delta
						if (not observers[id].visible) and observers[id].visible_time > minimum_visible_time:
							observers[id].visible = true
							visible_to.emit.call_deferred(observer)
							observer.notified_visible(_body)
						observers[id].hidden_time = 0
					else:
						observers[id].visible_time = 0
						if observers[id].visible:
							if observers[id].hidden_time > minimum_hidden_time:
								observers[id].visible = false
								hidden_to.emit.call_deferred(observer)
								observer.notified_hidden(_body)
						observers[id].hidden_time += delta

func _get_shape_aabb(shape_type:PhysicsServer3D.ShapeType,shape_data:Variant, trans: Transform3D) -> PackedVector3Array:
	var points: PackedVector3Array = PackedVector3Array()
	var sqrt_3 = sqrt(3.0)
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
			#this gets an aabb within the sphere
			# to get one that contains the sphere, we can use just the radius
			var r = shape_data / sqrt_3  # Adjust radius for sphere
			points.append_array([
				trans.origin + trans.basis * Vector3(-r, -r, -r),
				trans.origin + trans.basis * Vector3(-r, -r, r),
				trans.origin + trans.basis * Vector3(-r, r, -r),
				trans.origin + trans.basis * Vector3(-r, r, r),
				trans.origin + trans.basis * Vector3(r, -r, -r),
				trans.origin + trans.basis * Vector3(r, -r, r),
				trans.origin + trans.basis * Vector3(r, r, -r),
				trans.origin + trans.basis * Vector3(r, r, r),
			])
		PhysicsServer3D.SHAPE_CAPSULE,PhysicsServer3D.SHAPE_CYLINDER:
			var h = shape_data.height * 0.5
			var radius = shape_data.radius
			# For AABB within capsule: Y is constrained by cylindrical portion, X/Z by circular cross-section
			var y_extent:float
			if shape_type == PhysicsServer3D.SHAPE_CAPSULE:
				y_extent = h - radius  # Height minus the spherical caps
			else:
				y_extent = h  # Cylinder has no spherical caps, so full height is used
			var xz_extent = radius / sqrt(2.0)  # Largest square that fits in circle
			points.append_array([
				trans.origin + trans.basis * Vector3(-xz_extent, -y_extent, -xz_extent),
				trans.origin + trans.basis * Vector3(-xz_extent, -y_extent, xz_extent),
				trans.origin + trans.basis * Vector3(-xz_extent, y_extent, -xz_extent),
				trans.origin + trans.basis * Vector3(-xz_extent, y_extent, xz_extent),
				trans.origin + trans.basis * Vector3(xz_extent, -y_extent, -xz_extent),
				trans.origin + trans.basis * Vector3(xz_extent, -y_extent, xz_extent),
				trans.origin + trans.basis * Vector3(xz_extent, y_extent, -xz_extent),
				trans.origin + trans.basis * Vector3(xz_extent, y_extent, xz_extent),
			])
		_:
			# For other shapes, we can return an empty array or handle them as needed
			push_error("Unsupported shape type:", shape_type)
			return PackedVector3Array()
	return points

func _random_point_within_points(points: PackedVector3Array) -> Vector3:
	if points.is_empty():
		return Vector3.ZERO
	var min_bounds = points[0]
	var max_bounds = points[0]
	for point in points:
		min_bounds = min_bounds.min(point)
		max_bounds = max_bounds.max(point)
	var random_point = Vector3(
		randf_range(min_bounds.x, max_bounds.x),
		randf_range(min_bounds.y, max_bounds.y),
		randf_range(min_bounds.z, max_bounds.z)
	)
	return random_point


func _on_area_entered(area: Area3D) -> void:
	if not enabled:
		return
	var area_parent = area.get_parent()
	if area_parent is Observer:
		if observers.has(area_parent.get_instance_id()):
			if not observers[area_parent.get_instance_id()].visible:
				# If the observer is already visible, we don't need to do anything
				return
			observers[area_parent.get_instance_id()]["visible"] = true
			observers[area_parent.get_instance_id()]["visible_time"] = 0.0
			observers[area_parent.get_instance_id()]["hidden_time"] = 0.0
		else:
			if mode == OBSERVER_NOTIFIER_MODE.OBSERVATION:
				visible_to.emit.call_deferred(area_parent)
				area_parent.notified_visible(_body)
			else:
				observers[area_parent.get_instance_id()] = {
					"visible": false,
					"visible_time": 0.0,
					"hidden_time": 0.0,
				}

func _on_area_exited(area: Area3D) -> void:
	var area_parent = area.get_parent()
	if area_parent is Observer:
		if mode == OBSERVER_NOTIFIER_MODE.OBSERVATION:
			hidden_to.emit.call_deferred(area_parent)
			area_parent.notified_hidden(_body)
		else:
			if observers.has(area_parent.get_instance_id()):
				if observers[area_parent.get_instance_id()].visible:
					observers.erase(area_parent.get_instance_id())
					hidden_to.emit.call_deferred(area_parent)
					area_parent.notified_hidden(_body)

func _notification(what: int) -> void:
	if what == NOTIFICATION_READY:
		_initialize()
		_setup()
		set_physics_process(enabled)  # Enable or disable physics processing based on enabled state
	if what == NOTIFICATION_PHYSICS_PROCESS:
		if mode == OBSERVER_NOTIFIER_MODE.OBSERVATION:
			return
		check_counter += 1
		if check_counter >= occlusion_check_frequency:
			check_counter = 0
			_check_visibility(get_physics_process_delta_time() * local_time_scale)
