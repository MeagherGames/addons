@tool
extends RefCounted

const ASEPRITE_PATH_KEY = "filesystem/import/aseprite/path"


static func get_global_filepath(filepath) -> String:
	return ProjectSettings.globalize_path(filepath)

static func get_output_path(filepath) -> String:
	var name: String = filepath.get_file()
	return OS.get_cache_dir().path_join("%s/%s.json" % [ProjectSettings.get_setting("application/config/name"), name])

static func test_aseprite_path(file_path: String) -> bool:
	if file_path == "":
		return false
	if execute(file_path, ["--version"]) != OK:
		return false
	return true

static func set_aseprite_path(path: String) -> void:
	var editor_settings = EditorInterface.get_editor_settings()
	editor_settings.set(ASEPRITE_PATH_KEY, path)
	editor_settings.add_property_info({
		name = ASEPRITE_PATH_KEY,
		type = TYPE_STRING,
		hint = PROPERTY_HINT_GLOBAL_FILE
	})
	editor_settings.set_initial_value(ASEPRITE_PATH_KEY, "", false)
	prints("Set aseprite path to:", path)

static func find_aseprite() -> String:
	var editor_settings = EditorInterface.get_editor_settings()

	if editor_settings.has_setting(ASEPRITE_PATH_KEY):
		var aseprite_path = editor_settings.get(ASEPRITE_PATH_KEY)
		if test_aseprite_path(aseprite_path):
			return aseprite_path

	var paths: PackedStringArray = []
	match OS.get_name():
		"Windows":
			var output = []
			OS.execute("cmd", ["/c", "ftype", "AsepriteFile"], output, true)
			for ftype in output:
				var exe_path = ftype.split("=", false, 1)[1]
				paths.append(exe_path)

			paths.append("C:/Program Files (x86)/Steam/steamapps/common/Aseprite/Aseprite.exe")
			paths.append("C:/Program Files (x86)/Aseprite/Aseprite.exe")
			paths.append("C:/Program Files/Aseprite/Aseprite.exe")

		"iOS", "macOS":
			paths.append("~/Library/ApplicationSupport/Steam/steamapps/common/Aseprite/Aseprite.app/Contents/MacOS/aseprite")
			paths.append("~/Library/Application Support/Steam/SteamApps/common/Aseprite/Aseprite.app/Contents/MacOS/aseprite")
			paths.append("/Applications/Aseprite.app/Contents/MacOS/aseprite")

		"Linux", "FreeBSD", "NetBSD", "OpenBSD", "BSD":
			# I haven't tested this
			var output = []
			OS.execute("find", [
				"~/.steam/steam/steamapps/common",
				"~/.local/bin",
				"/usr/local/bin",
				"/opt",
				"-name",
				"aseprite*"
			], output, true)
			for path in output:
				paths.append(path)
	
	
	for path in paths:
		if FileAccess.file_exists(path) and test_aseprite_path(path):
			set_aseprite_path(path)
			return path

	push_warning("Aseprite not found. Please set the path to Aseprite in the Editor Settings. (Editor > Editor Settings -> Filesystem -> Import -> Aseprite -> Path)")
	set_aseprite_path("")
	return ""

static func execute(command: String, arguments: Array = [], print_output = false) -> int:
	var res: int = OK
	if print_output:
		print("Executing \"", command, "\" with arguments: ", arguments)
		var output = []
		var args = [
			"--debug", # Enable debug mode
			"--verbose", # Enable verbose mode
		]
		args.append_array(arguments)
		print("Executing \"", command, "\" with arguments: ", args)
		res = OS.execute(command, args, output, true, true)
		if res != OK:
			printerr("Unable to execute \"", command, "\" Error Code ", res, ":\n", "\n".join(PackedStringArray(output)))
	else:
		res = OS.execute(command, arguments)
	
	return res

static func execute_script(script_path: String, parameters: Dictionary = {}, print_output = false) -> int:
	var aseprite_path = find_aseprite()
	var arguments = [
		"--batch", # Don't open UI
	]
	for param in parameters:
		if typeof(param) == TYPE_NIL or (typeof(param) == TYPE_STRING and param == ""):
			continue
		arguments.append_array([
			"--script-param", "%s=%s" % [param, parameters[param]]
		])
	arguments.append_array(["--script", script_path])
	
	return execute(aseprite_path, arguments, print_output)

static func load_file(filepath: String, options: Dictionary = {}) -> Dictionary:
	var aseprite_path = find_aseprite()
	if aseprite_path == "":
		printerr("Aseprite Not Found! Please set the path to Aseprite in the Editor Settings. (Editor > Editor Settings -> Filesystem -> Import -> Aseprite -> Path)")
		return {}

	if options.get("debug", false):
		print(options)
	
	return _load_data(filepath, options)

static func _load_data(filepath: String, options: Dictionary = {}) -> Dictionary:
	var scene_script_path = ProjectSettings.globalize_path("res://addons/aseprite-importer/Aseprite/aseprite_scripts/export.lua")
	if not FileAccess.file_exists(scene_script_path):
		printerr("Unable to import \"%s\" script at \"%s\" not found" % [filepath, scene_script_path])
		return {}

	var output_path = get_output_path(filepath)
	var args = {
		file_path = get_global_filepath(filepath),
		output_path = output_path,
		layers = options.get("layers", false),
		tiles = options.get("tiles", false),
		pack_mode = options.get("pack_mode", null),
	}
	if execute_script(scene_script_path, args, options.get("debug", false)) != OK:
		printerr("Unable to import %s" % filepath)
		return {}

	var json = JSON.new()
	var data = FileAccess.open(output_path, FileAccess.READ)
	if data == null:
		printerr("Unable to open scene file ", output_path, " [Error ", FileAccess.get_open_error(), "]")
		return {}
	json.parse(data.get_as_text())
	if json.data == null:
		printerr("Unable to parse JSON data ", output_path, json.get_error_message())
		return {}

	return json.data
