@tool
extends Resource

var aseprite:RefCounted
var editor_settings:EditorSettings

func get_global_filepath(filepath) -> String:
	return ProjectSettings.globalize_path(filepath)

func get_data_path(filepath) -> String:
	var name:String = filepath.get_file()
	return OS.get_cache_dir().path_join("%s/%s-data.json" % [ProjectSettings.get_setting("application/config/name"), name])

func get_sheet_path(filepath) -> String:
	var name:String = filepath.get_file()
	return OS.get_cache_dir().path_join("%s/%s-sheet.png" % [ProjectSettings.get_setting("application/config/name"), name])

func get_user_data_path(filepath) -> String:
	var name:String = filepath.get_file()
	return OS.get_cache_dir().path_join("%s/%s-user-data.json" % [ProjectSettings.get_setting("application/config/name"), name])

func get_tile_set_data_path(filepath) -> String:
	var name:String = filepath.get_file()
	return OS.get_cache_dir().path_join("%s/%s-tile-set-data.json" % [ProjectSettings.get_setting("application/config/name"), name])

func test_aseprite_path(file_path:String) -> bool:
	if file_path == "":
		return false
	if OS.execute(file_path, ["--version"]) == -1:
		return false
	return true

func find_aseprite() -> String:

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