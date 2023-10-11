@tool
extends RefCounted

const AsepriteFile = preload("./AsepriteFile.gd")

var context = null

func _init(context):
	self.context = context
	context.aseprite = self

func execute_script(script_path:String, parameters:Dictionary = {}, print_output = false) -> int:
	var aseprite_path = context.find_aseprite()
	var arguments = [
		"--batch", # Don't open UI
	]
	for param in parameters:
		arguments.append_array([
			"--script-param", "%s=%s" % [param, parameters[param]]
		])
	arguments.append_array(["--script", script_path])
	
	var res:int = -1
	if print_output:
		var output = []
		res = OS.execute(aseprite_path, arguments, output, true)
		print("\n".join(PackedStringArray(output)))
	else:
		res = OS.execute(aseprite_path, arguments)
	
	return res

func load_file(filepath:String, options:Dictionary = {}) -> RefCounted:
	var aseprite_path = context.find_aseprite()
	if aseprite_path == "":
		return null

	var aseprite_file = AsepriteFile.new()
	var global_filepath = context.get_global_filepath(filepath)
	var data_path = context.get_data_path(filepath)
	var sheet_path = context.get_sheet_path(filepath)
	var user_data_path = context.get_user_data_path(filepath)
	var json:JSON = JSON.new()
	
	# See https://www.aseprite.org/docs/cli/
	var arguments = [
		"--batch", # Don't open UI
		"--format", "json-array", # export data as json
		"--list-tags" # get animation tags
	]

	if options.get("split_layers", false):
		arguments.append_array([
			"--list-layers", # get layer names
			"--split-layers" # export each layer as a separate image
		])

	arguments.append_array([
		"--data", data_path,
		"--sheet-type", "packed",
		"--sheet", sheet_path,
		global_filepath
	])
	
	OS.execute(aseprite_path, arguments)
	execute_script(
		ProjectSettings.globalize_path("%s/aseprite_scripts/user_data.lua" % [get_script().get_path().get_base_dir()]),
		{
			file_path = global_filepath,
			output_path = user_data_path
		}
	)
	
	# Sprite sheet, data, and user data into the AsepriteFile
	aseprite_file.image = Image.load_from_file(sheet_path)

	var data_file = FileAccess.open(data_path, FileAccess.READ)
	if data_file == null:
		printerr("Unable to open data file ", data_path)
		return null
	json.parse(data_file.get_as_text())

	if json.data == null:
		printerr("Unable to parse JSON data ", data_path, json.get_error_message())
		return null
	aseprite_file.data = json.data
	
	var user_data_file = FileAccess.open(user_data_path, FileAccess.READ)
	if user_data_file == null:
		printerr("Unable to open user data file ", user_data_path)
		return null
	json.parse(user_data_file.get_as_text())

	if json.data == null:
		printerr("Unable to parse JSON data ", user_data_path, json.get_error_message())
		return null
		
	aseprite_file.user_data = json.data.user_data

	# Normalize the data
	aseprite_file.normalize()

	return aseprite_file
