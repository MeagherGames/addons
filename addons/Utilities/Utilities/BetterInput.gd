extends Node

# TODO allow getting the player simplified device name (e.g. "Joy-Con (L)", "Joy-Con (R)", "Pro Controller", "Xbox", "PS4", etc.)
# So that we can show the correct button icons in the UI for each player

signal player_added(player_index: int)
signal player_removed(player_index: int)

const JOY_DEVICE_INVALID = 8

var core_actions = []
var device_actions = {} # { device: { core_action: device_action } }
var player_devices:PackedInt32Array = [-1] # [ device, ... ]

func _init():
	reset()

func reset():
	InputMap.load_from_project_settings()
	core_actions = InputMap.get_actions()

	# disable joypad events in all actions
	for action in core_actions:
		for event in InputMap.action_get_events(action):
			if _is_joypad_event(event):
				# Set device out of range to disable the action
				event.device = JOY_DEVICE_INVALID

	for device in Input.get_connected_joypads():
		_add_player(device)
		_create_actions_for_device(device)

	if !Input.joy_connection_changed.is_connected(on_joy_connection_changed):
		Input.joy_connection_changed.connect(on_joy_connection_changed)

func on_joy_connection_changed(device: int, connected: bool):
	if connected:
		# add player
		_add_player(device)
		_create_actions_for_device(device)
	else:
		_remove_player(device)
		_remove_actions_for_device(device)

func _add_player(device:int) -> void:
	var first_invalid = -1
	# if player 1 was keyboard, replace it with the new device
	if player_devices[0] == -1:
		player_devices[0] = device
		emit_signal("player_added", 0)
		return

	# search for the first invalid device
	for i in player_devices.size():
		if player_devices[i] == JOY_DEVICE_INVALID:
			first_invalid = i
		if player_devices[i] == device:
			# device already exists
			return
	
	if first_invalid >= 0:
		# if there is an invalid device, replace it with the new device
		player_devices[first_invalid] = device
		emit_signal("player_added", first_invalid)
	else:
		# otherwise, add the new device
		player_devices.append(device)
		emit_signal("player_added", player_devices.size() - 1)

func _remove_player(device:int) -> void:
	var index = player_devices.find(device)
	if index == 0:
		# if player 1 was the device, replace it with keyboard
		player_devices[0] = -1
		emit_signal("player_removed", 0)
	elif index > 0:
		player_devices[index] = JOY_DEVICE_INVALID
		emit_signal("player_removed", index)

func _create_actions_for_device(device: int) -> void:
	device_actions[device] = {}
	for core_action in core_actions:
		var action_name = "%d_%s" % [device, core_action]
		var deadzone = InputMap.action_get_deadzone(core_action)

		var joy_events = InputMap.action_get_events(core_action).filter(_is_joypad_event)

		if joy_events.size() == 0:
			continue

		InputMap.add_action(action_name, deadzone)
		device_actions[device][core_action] = action_name
		for event in joy_events:
			var new_event = event.duplicate()
			new_event.device = device
			InputMap.action_add_event(action_name, new_event)

func _remove_actions_for_device(device: int) -> void:
	device_actions.erase(device)
	var device_prefix = "%d_" % device

	var actions = InputMap.get_actions()
	for action in actions:
		if String(action).begins_with(device_prefix):
			InputMap.erase_action(action)

func _is_joypad_event(event: InputEvent) -> bool:
	return event is InputEventJoypadButton or event is InputEventJoypadMotion

func get_player_action(player_index: int, core_action: String) -> String:
	if player_index < 0 or player_index >= player_devices.size():
		return core_action
	var device = player_devices[player_index]
	if device == -1:
		return core_action
	
	return device_actions.get(device, {}).get(core_action, "")

func action_press(player_index:int, action:StringName, strength:float=1.0) -> void:
	action = get_player_action(player_index, action)
	Input.action_press(action, strength)

func action_release(player_index:int, action:StringName) -> void:
	action = get_player_action(player_index, action)
	Input.action_release(action)

func get_action_raw_strength(player_index:int, action:StringName, exact_match:bool=false) -> float:
	action = get_player_action(player_index, action)
	return Input.get_action_strength(action, exact_match)

func get_action_strength(player_index:int, action:StringName, exact_match:bool=false) -> float:
	action = get_player_action(player_index, action)
	return Input.get_action_strength(action, exact_match)

func get_axis(player_index:int, negative_action: StringName, positive_action: StringName) -> float:
	negative_action = get_player_action(player_index, negative_action)
	positive_action = get_player_action(player_index, positive_action)
	return Input.get_axis(negative_action, positive_action)

func get_vector(player_index:int, negative_x: StringName, positive_x: StringName, negative_y: StringName, positive_y: StringName, deadzone: float = -1.0) -> Vector2:
	negative_x = get_player_action(player_index, negative_x)
	positive_x = get_player_action(player_index, positive_x)
	negative_y = get_player_action(player_index, negative_y)
	positive_y = get_player_action(player_index, positive_y)
	return Input.get_vector(negative_x, positive_x, negative_y, positive_y, deadzone)

func is_action_just_pressed(player_index:int, action: StringName, exact_match: bool = false) -> bool:
	action = get_player_action(player_index, action)
	return Input.is_action_just_pressed(action, exact_match)

func is_action_just_released(player_index:int, action: StringName, exact_match: bool = false) -> bool:
	action = get_player_action(player_index, action)
	return Input.is_action_just_released(action, exact_match)

func is_action_pressed(player_index:int, action: StringName, exact_match: bool = false) -> bool:
	action = get_player_action(player_index, action)
	return Input.is_action_pressed(action, exact_match)