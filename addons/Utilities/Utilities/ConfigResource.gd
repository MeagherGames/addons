class_name ConfigResource extends Resource

func save_to_file(path:String) -> void:
	var config := ConfigFile.new()
	var properties = get_property_list()
	var category = ""
	for property in properties:
		var usage = property.get("usage", 0)
		if usage & PROPERTY_USAGE_CATEGORY:
			category = property.name
		elif usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			config.set_value(category, property.name, get(property.name))
	
	config.save(path)

func load_from_file(path:String) -> void:
	var config := ConfigFile.new()
	if config.load(path) == OK:
		for section in config.get_sections():
			for property in config.get_section_keys(section):
				if property in self:
					var value = config.get_value(section, property, self.get(property))
					set(property, value)
		_validate()
		emit_changed()

func _validate() -> void:
	pass # Override this method in your script to validate the loaded data