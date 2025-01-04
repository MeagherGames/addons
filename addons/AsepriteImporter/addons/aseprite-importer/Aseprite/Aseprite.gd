@tool
extends RefCounted

const AsepriteFile = preload("res://addons/aseprite-importer/Aseprite/AsepriteFile.gd")

static func get_global_filepath(filepath) -> String:
	return ProjectSettings.globalize_path(filepath)

static func get_data_path(filepath) -> String:
	var name:String = filepath.get_file()
	return OS.get_cache_dir().path_join("%s/%s-data.json" % [ProjectSettings.get_setting("application/config/name"), name])

static func get_sheet_path(filepath) -> String:
	var name:String = filepath.get_file()
	return OS.get_cache_dir().path_join("%s/%s-sheet.png" % [ProjectSettings.get_setting("application/config/name"), name])

static func get_user_data_path(filepath) -> String:
	var name:String = filepath.get_file()
	return OS.get_cache_dir().path_join("%s/%s-user-data.json" % [ProjectSettings.get_setting("application/config/name"), name])

static func get_tile_set_data_path(filepath) -> String:
	var name:String = filepath.get_file()
	return OS.get_cache_dir().path_join("%s/%s-tile-set-data.json" % [ProjectSettings.get_setting("application/config/name"), name])

static func test_aseprite_path(file_path:String) -> bool:
	if file_path == "":
		return false
	if execute(file_path, ["--version"]) != OK:
		return false
	return true

static func find_aseprite() -> String:
	var editor_settings = EditorInterface.get_editor_settings()

	if "filesystem/import/aseprite/path" in editor_settings:
		var aseprite_path = editor_settings.get("filesystem/import/aseprite/path")
		if test_aseprite_path(aseprite_path):
			return aseprite_path

	var locations:PackedStringArray = []
	match OS.get_name():
		"Windows":
			var output = [ ]
			OS.execute("cmd", ["/c", "ftype", "AsepriteFile"], output, true)
			for ftype in output:
				var exe_path = ftype.split("=", false, 1)[1]
				locations.append(exe_path)

			locations.append("C:/Program Files (x86)/Steam/steamapps/common/Aseprite/Aseprite.exe")
			locations.append("C:/Program Files (x86)/Aseprite/Aseprite.exe")
			locations.append("C:/Program Files/Aseprite/Aseprite.exe")

		"iOS":
			locations.append("~/Library/ApplicationSupport/Steam/steamapps/common/Aseprite/Aseprite.app/Contents/MacOS/aseprite")
			locations.append("~/Library/Application Support/Steam/SteamApps/common/Aseprite/Aseprite.app/Contents/MacOS/aseprite")
			locations.append("/Applications/Aseprite.app/Contents/MacOS/aseprite")

		"macOS":
			locations.append("~/Library/ApplicationSupport/Steam/steamapps/common/Aseprite/Aseprite.app/Contents/MacOS/aseprite")
			locations.append("~/Library/Application Support/Steam/SteamApps/common/Aseprite/Aseprite.app/Contents/MacOS/aseprite")
			locations.append("/Applications/Aseprite.app/Contents/MacOS/aseprite")

	for location in locations:
		if FileAccess.file_exists(location) and test_aseprite_path(location):
			editor_settings.set("filesystem/import/aseprite/path", location)
			editor_settings.add_property_info({
				name = "filesystem/import/aseprite/path",
				type = TYPE_STRING,
				hint = PROPERTY_HINT_GLOBAL_FILE
			})
			return location

	push_warning("Aseprite not found. Please set the path to Aseprite in the Editor Settings. (Project -> Project Settings -> Filesystem -> Import -> Aseprite -> Path)")
	editor_settings.set("filesystem/import/aseprite/path", "")
	editor_settings.add_property_info({
		name = "filesystem/import/aseprite/path",
		type = TYPE_STRING,
		hint = PROPERTY_HINT_GLOBAL_FILE
	})
	return ""

static func execute(command:String, arguments:Array = [], print_output = false) -> int:
	var res:int = -1
	if print_output:
		var output = []
		res = OS.execute(command, arguments, output, true, true)
		if res != OK:
			printerr("Unable to execute \"", command,  "\" Error Code ", res, ":\n", "\n".join(PackedStringArray(output)))
	else:
		res = OS.execute(command, arguments)
	
	return res

static func execute_script(script_path:String, parameters:Dictionary = {}, print_output = false) -> int:
	var aseprite_path = find_aseprite()
	var arguments = [
		"--batch", # Don't open UI
	]
	for param in parameters:
		arguments.append_array([
			"--script-param", "%s=%s" % [param, parameters[param]]
		])
	arguments.append_array(["--script", script_path])
	
	return execute(aseprite_path, arguments, print_output)

static func load_file(filepath:String, options:Dictionary = {}) -> AsepriteFile:
	var aseprite_path = find_aseprite()
	if aseprite_path == "":
		return null

	var global_filepath = get_global_filepath(filepath)
	var data_path = get_data_path(filepath)
	var sheet_path = get_sheet_path(filepath)
	var user_data_path = get_user_data_path(filepath)
	var json:JSON = JSON.new()
	
	# See https://www.aseprite.org/docs/cli/
	var arguments = [
		# "--debug", # Enable debug mode
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
		"--sheet", sheet_path,
		global_filepath
	])
	
	if execute(aseprite_path, arguments) != OK:
		printerr("Unable to execute Aseprite")
		return null
	
	if execute_script(
		ProjectSettings.globalize_path("res://addons/aseprite-importer/Aseprite/aseprite_scripts/user_data.lua"),
		{
			file_path = global_filepath,
			output_path = user_data_path
		}
	) != OK:
		printerr("Unable to execute user data script")
		return null
	
	# Sprite sheet, data, and user data into the AsepriteFile
	var aseprite_file_image:Image = Image.load_from_file(sheet_path)
	var aseprite_file_data:Dictionary
	var aseprite_file_user_data:Array

	var data_file = FileAccess.open(data_path, FileAccess.READ)
	if data_file == null:
		printerr("Unable to open data file ", data_path, " [Error ", FileAccess.get_open_error(), "]")
		return null
	json.parse(data_file.get_as_text())

	if json.data == null:
		printerr("Unable to parse JSON data ", data_path, json.get_error_message())
		return null
	aseprite_file_data = json.data
	
	var user_data_file = FileAccess.open(user_data_path, FileAccess.READ)
	if user_data_file == null:
		printerr("Unable to open user data file ", user_data_path, " [Error ", FileAccess.get_open_error(), "]")
		return null
	json.parse(user_data_file.get_as_text())

	if json.data == null:
		printerr("Unable to parse JSON data ", user_data_path, json.get_error_message())
		return null
		
	aseprite_file_user_data = json.data.user_data

	# Normalize the data
	return AsepriteFile.new(aseprite_file_image, aseprite_file_data, aseprite_file_user_data)
