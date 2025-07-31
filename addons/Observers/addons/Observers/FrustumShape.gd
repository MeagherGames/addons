
class_name FrustumShape extends ConvexPolygonShape3D
@export var view_size: Vector2 = Vector2.ZERO: # Size of the viewport for the viewer
	set = set_view_size
@export var fov: float = 75.0: # Vertical field of view in degrees
	set = set_fov
@export var far: float = 1000.0: # Far clipping distance
	set = set_far
@export var near: float = 0.1: # Near clipping distance
	set = set_near

func _init() -> void:
	# Initialize the frustum shape based on the view size, FOV, far and near distances
	points = _get_frustum_points()

func set_view_size(value: Vector2) -> void:
	view_size = value
	points = _get_frustum_points()

func set_fov(value: float) -> void:
	fov = value
	points = _get_frustum_points()

func set_far(value: float) -> void:
	far = value
	points = _get_frustum_points()

func set_near(value: float) -> void:
	near = value
	points = _get_frustum_points()


func _get_frustum_points() -> PackedVector3Array:
	var aspect_ratio = view_size.x / view_size.y
	var vfov = fov  # Camera FOV is vertical in Godot
	var hfov = 2.0 * rad_to_deg(atan(tan(deg_to_rad(vfov / 2.0)) * aspect_ratio))
	var near_center = Vector3(tan(deg_to_rad(hfov / 2)) * near,	tan(deg_to_rad(vfov / 2)) * near, near)
	var far_center = Vector3(tan(deg_to_rad(hfov / 2)) * far, tan(deg_to_rad(vfov / 2)) * far, far)
	var points = PackedVector3Array([
		Vector3(-near_center.x, -near_center.y, -near_center.z), # Bottom-left near
		Vector3(near_center.x, -near_center.y, -near_center.z),  # Bottom-right near
		Vector3(near_center.x, near_center.y, -near_center.z),   # Top-right near
		Vector3(-near_center.x, near_center.y, -near_center.z),  # Top-left near
		Vector3(-far_center.x, -far_center.y, -far_center.z),    # Bottom-left far
		Vector3(far_center.x, -far_center.y, -far_center.z),     # Bottom-right far
		Vector3(far_center.x, far_center.y, -far_center.z),      # Top-right far
		Vector3(-far_center.x, far_center.y, -far_center.z)      # Top-left far
	])
	return points