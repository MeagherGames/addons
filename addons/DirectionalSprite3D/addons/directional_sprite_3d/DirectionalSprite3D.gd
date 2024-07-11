@tool
extends Node3D

const SpriteShader = preload("res://addons/directional_sprite_3d/directional_sprite_shader_3d.gdshader")

@export var texture:Texture2D : set = set_texture

@export var offset:Vector2 = Vector2.ZERO : set = set_offset
@export var is_centered:bool = true : set = set_is_centered
@export var pixels_per_meter:float = 32.0 : set = set_pixels_per_meter
@export_group("Animation")
@export var frame_size:Vector2 = Vector2(32,32) : set = set_frame_size
@export var frame:int = 0 : set = set_frame
@export_group("Regions")
@export var regions_enabled:bool = false :
    set(value):
        regions_enabled = value
        _update_regions()
@export var front_region:Vector4 = Vector4(0,0,0,0.25) :
    set(value):
        front_region = value
        _update_regions()
@export var left_region:Vector4 = Vector4(0,0.25,0,0.5) :
    set(value):
        left_region = value
        _update_regions()
@export var right_region:Vector4 = Vector4(0,0.5,0,0.75) :
    set(value):
        right_region = value
        _update_regions()
@export var back_region:Vector4 = Vector4(0,0.75,0,1) :
    set(value):
        back_region = value
        _update_regions()
@export_group("Material")
@export var flip_h:bool = false : set = set_flip_h
@export var flip_v:bool = false : set = set_flip_v
@export var modulate:Color = Color(1,1,1,1) : set = set_modulate
@export_range(0.0, 1.0) var alpha_scissor_threshold:float = 0.5 : set = set_alpha_scissor_threshold
@export_range(0.0, 1.0) var specular:float = 0.5 : set = set_specular
@export_range(0.0, 1.0) var metallic:float = 0.0 : set = set_metallic
@export_range(0.0, 1.0) var roughness:float = 1.0 : set = set_roughness
@export_enum("billboard", "billboard_y") var billboard_mode:int = 0 : set = set_billboard_mode
@export_enum("cardinal", "diagonal") var side_mode:int = 0 : set = set_side_mode
@export var cast_shadow:RenderingServer.ShadowCastingSetting = RenderingServer.SHADOW_CASTING_SETTING_ON : set = set_cast_shadow

var instance:RID
var mesh:RID
var material:RID

var _is_drawing:bool = false

func _init():
    instance = RenderingServer.instance_create()
    mesh = RenderingServer.mesh_create()
    material = RenderingServer.material_create()

    RenderingServer.instance_attach_object_instance_id(instance, get_instance_id())
    RenderingServer.instance_set_base(instance, mesh)
    set_notify_transform(true)

    _queue_draw()

func _queue_draw():
    if _is_drawing:
        return
    _is_drawing = true
    _draw.call_deferred()

func _draw():
    if not is_inside_tree():
        return

    if not texture:
        RenderingServer.instance_set_base(instance, RID())
        return
    else:
        RenderingServer.instance_set_base(instance, mesh)

    generate_mesh()
    RenderingServer.material_set_shader(material, SpriteShader.get_rid())

    _is_drawing = false

func _update_visibility():
    RenderingServer.instance_set_visible(instance, is_visible_in_tree())

func _notification(what):
    match what:
        NOTIFICATION_ENTER_WORLD:
            RenderingServer.instance_set_scenario(instance, get_world_3d().get_scenario())
            _update_visibility()
        NOTIFICATION_TRANSFORM_CHANGED:
            RenderingServer.instance_set_transform(instance, get_global_transform())
        NOTIFICATION_EXIT_WORLD:
            RenderingServer.instance_set_scenario(instance, RID())
        NOTIFICATION_VISIBILITY_CHANGED:
            _update_visibility()
        NOTIFICATION_PREDELETE:
            RenderingServer.free_rid(instance)
            RenderingServer.free_rid(mesh)
            RenderingServer.free_rid(material)
        

func get_item_rect() -> Rect2:
    if not texture:
        return Rect2(0,0,1,1)

    @warning_ignore("shadowed_variable")
    var offset:Vector2 = self.offset
    
    var size = frame_size

    if is_centered:
        offset -= size / 2.0
    
    
    if size == Vector2.ZERO:
        size = Vector2(1,1)
    
    return Rect2(offset , size)

func _swap(arr, i, j):
    var temp = arr[i]
    arr[i] = arr[j]
    arr[j] = temp

func generate_mesh() -> void:

    var rect:Rect2 = get_item_rect()
    var aabb:AABB = AABB()
    var pixel_size = 1.0 / pixels_per_meter

    var vertices:PackedVector3Array = [
        Vector3(rect.position.x, rect.position.y, 0) * pixel_size,
        Vector3(rect.position.x + rect.size.x, rect.position.y, 0) * pixel_size,
        Vector3(rect.position.x + rect.size.x, rect.position.y + rect.size.y, 0) * pixel_size,
        Vector3(rect.position.x, rect.position.y + rect.size.y, 0) * pixel_size
    ]

    for v in vertices:
        aabb = aabb.expand(v)

    var uvs:PackedVector2Array = [
        Vector2(0, 1),
        Vector2(1, 1),
        Vector2(1, 0),
        Vector2(0, 0)
    ]

    if flip_h:
        _swap(uvs, 0, 1)
        _swap(uvs, 2, 3)
    
    if flip_v:
        _swap(uvs, 0, 3)
        _swap(uvs, 1, 2)
        

    var indices:PackedInt32Array = [0, 3, 2, 0, 2, 1]
    var colors:PackedColorArray = [modulate, modulate, modulate, modulate]

    var arrays = []
    arrays.resize(RenderingServer.ARRAY_MAX)
    arrays[RenderingServer.ARRAY_VERTEX] = vertices
    arrays[RenderingServer.ARRAY_COLOR] = colors
    arrays[RenderingServer.ARRAY_TEX_UV] = uvs
    arrays[RenderingServer.ARRAY_INDEX] = indices

    RenderingServer.mesh_clear(mesh)
    RenderingServer.mesh_add_surface_from_arrays(mesh, RenderingServer.PRIMITIVE_TRIANGLES, arrays)
    RenderingServer.mesh_set_custom_aabb(mesh, aabb)

    # Material
    RenderingServer.mesh_surface_set_material(mesh, 0, material)
    RenderingServer.material_set_param(material, "texture_albedo", texture.get_rid())
    RenderingServer.material_set_param(material, "alpha_scissor_threshold", alpha_scissor_threshold)
    _update_regions()

func _update_regions():
    if not texture:
        return

    if regions_enabled:
        RenderingServer.material_set_param(material, "front_region", front_region)
        RenderingServer.material_set_param(material, "left_region", left_region)
        RenderingServer.material_set_param(material, "right_region", right_region)
        RenderingServer.material_set_param(material, "back_region", back_region)
    else:
        # We're just going to expect that directional angles are split vertically
        # while animation frames are always split horizontally
        var texture_size:Vector2 = texture.get_size()
        var frame_offset:Vector2 = Vector2(frame_size.x * frame, 0) / texture_size
        var region_size:Vector2 = frame_size / texture_size

        var regions = ["front_region", "left_region", "right_region", "back_region"]
        for i in regions.size():
            var region_offset =  frame_offset + (Vector2(0, frame_size.y * i)  / texture_size)
            var region:Vector4 = Vector4(
                region_offset.x,
                region_offset.y,
                region_offset.x + region_size.x,
                region_offset.y + region_size.y
            )
            RenderingServer.material_set_param(material, regions[i], region)


func set_texture(value:Texture2D) -> void:
    if texture:
        texture.changed.disconnect(_queue_draw)
    texture = value
    if texture:
        texture.changed.connect(_queue_draw)
    _queue_draw()

func set_offset(value:Vector2) -> void:
    offset = value
    _queue_draw()

func set_is_centered(value:bool) -> void:
    is_centered = value
    _queue_draw()

func set_pixels_per_meter(value:float) -> void:
    pixels_per_meter = value
    _queue_draw()

func set_frame_size(value:Vector2) -> void:
    frame_size = value
    _queue_draw()

func set_frame(value:int) -> void:
    if frame == value:
        return
    
    frame = value
    _update_regions()

func set_flip_h(value:bool) -> void:
    flip_h = value
    _queue_draw()

func set_flip_v(value:bool) -> void:
    flip_v = value
    _queue_draw()

func set_modulate(value:Color) -> void:
    modulate = value
    _queue_draw()

func set_alpha_scissor_threshold(value:float) -> void:
    alpha_scissor_threshold = value
    RenderingServer.material_set_param(material, "alpha_scissor_threshold", alpha_scissor_threshold)

func set_specular(value:float) -> void:
    specular = value
    RenderingServer.material_set_param(material, "specular", specular)

func set_metallic(value:float) -> void:
    metallic = value
    RenderingServer.material_set_param(material, "metallic", metallic)

func set_roughness(value:float) -> void:
    roughness = value
    RenderingServer.material_set_param(material, "roughness", roughness)

func set_billboard_mode(value:int) -> void:
    billboard_mode = value
    RenderingServer.material_set_param(material, "billboard_y", billboard_mode == 1)

func set_side_mode(value:int) -> void:
    side_mode = value
    RenderingServer.material_set_param(material, "cardinal_sides", side_mode == 0)

func set_cast_shadow(value:RenderingServer.ShadowCastingSetting) -> void:
    cast_shadow = value
    RenderingServer.instance_geometry_set_cast_shadows_setting(instance, cast_shadow)