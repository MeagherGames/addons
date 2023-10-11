@tool
extends EditorImportPlugin

const sprite2d = preload("./sprite2d.gd")
const sprite3d = preload("./sprite3d.gd")
const directionalsprite3d = preload("./directionalsprite3d.gd")


enum PRESETS {
	SPRITE2D,
	SPRITE3D
}

var context = null

func _init(context):
	self.context = context

func _get_importer_name():
	return "MeagherGames.asprite_sprite_importer"

func _get_visible_name():
	return "Aseprite Sprite Importer"

func _get_recognized_extensions():
	return ["aseprite", "ase"]

func _get_save_extension():
	return "tscn"

func _get_resource_type():
	return "PackedScene"

func _get_preset_count():
	return PRESETS.size()

func _get_preset_name(preset:int):
	match preset:
		PRESETS.SPRITE2D:
			return "Sprite2D"
		PRESETS.SPRITE3D:
			return "Sprite3D"
		_:
			return "Unknown"

func _get_option_visibility(path: String, option_name:StringName, options: Dictionary) -> bool:

	if option_name == "pixel_size" || option_name == "split_layers":
		return true
	if option_name == "3D":
		# 3D is a hidden option
		# used to just switch between the 2D and 3D importers
		return false
	
	# 3D options visibility
	if options.get("3D", false):
		if option_name == "flags" or option_name.begins_with("flags/"):
			return true
		if option_name == "directional":
			return true
	
	return false
	

func _get_priority():
	return 1.0

func _get_import_order():
	return IMPORT_ORDER_DEFAULT

func _get_import_options(path:String, preset:int):
	match preset:
		PRESETS.SPRITE2D, PRESETS.SPRITE3D:
			# Shared options
			var options = [
				{
					name = "3D",
					default_value = (preset == PRESETS.SPRITE3D),
				},
				{
					name = "pixel_size",
					default_value = 0.01
				},
				{
					name = "split_layers",
					default_value = true
				},
				{
					name = "directional",
					default_value = false
				},
			]

			# 3D options
			options.append_array([
				{
					name = "flags",
					default_value = null,
					property_hint = PROPERTY_HINT_NONE,
					hint_string = "flags/",
					usage = PROPERTY_USAGE_CATEGORY
				},
				{
					name = "flags/billboard",
					property_hint = PROPERTY_HINT_ENUM,
					hint_string = "Disabled:0,Enabled:1,Y-Billboard:2",
					default_value = BaseMaterial3D.BILLBOARD_DISABLED,
				},
				{
					name = "flags/transparent",
					default_value = true
				},
				{
					name = "flags/shaded",
					default_value = false
				},
				{
					name = "flags/double_sided",
					default_value = true
				},
				{
					name = "flags/no_depth_test",
					default_value = false
				},
				{
					name = "flags/fixed_size",
					default_value = false
				},
				{
					name = "flags/alpha_cut",
					property_hint = PROPERTY_HINT_ENUM,
					hint_string = "Disabled:0,Discard:1,Opaque Pre-Pass:2",
					default_value = Sprite3D.ALPHA_CUT_DISABLED,
				},
				{
					name = "flags/texture_filter",
					property_hint = PROPERTY_HINT_ENUM,
					hint_string = "Nearest:0,Linear:1,Nearest Mipmap:2, Linear Mipmap:3, Nearest Mipmap Anisotropic:4, Linear Mipmap Anisotropic:5",
					default_value = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS,
				},
				{
					name = "flags/render_priority",
					default_value = 0
				}
			])

			return options
		_:
			return []

func _import(source_file, save_path, options, platform_variants, gen_files):
	options["save_path"] = save_path
	var aseprite_file = context.aseprite.load_file(source_file, options)

	if aseprite_file == null:
		return FAILED
	
	var name = aseprite_file.data.meta.image.split(".")[0]
	options["name"] = name
	
	var scene:PackedScene = PackedScene.new()

	# if ResourceLoader.exists(source_file, "PackedScene"):
	# 	scene = ResourceLoader.load(source_file, "PackedScene") as PackedScene
	# 	if scene == null:
	# 		scene = PackedScene.new()
	# else:
	# 	scene = PackedScene.new()
	
	var sprite
	if options.get("3D", false):
		if options.get("directional", false) and aseprite_file.is_directional:
			sprite = directionalsprite3d.import(aseprite_file, options)
		else:
			sprite = sprite3d.import(aseprite_file, options)
	else:
		sprite = sprite2d.import(aseprite_file, options)
	
	if sprite == null:
		return FAILED
	
	sprite.set_meta("aseprite_user_data", [])

	var animation_player
	if options.get("3D", false):
		if options.get("directional", false) and aseprite_file.is_directional:
			animation_player = directionalsprite3d.setup_animation(sprite, aseprite_file, options)
		else:
			animation_player = sprite3d.setup_animation(sprite, aseprite_file, options)
	else:
		animation_player = sprite2d.setup_animation(sprite, aseprite_file, options)
	
	if animation_player:
		sprite.add_child(animation_player)
		animation_player.owner = sprite
	
	scene.pack(sprite)
	
	return ResourceSaver.save(scene, save_path + "." + _get_save_extension())
