@icon("./state_icon.png")
class_name State extends Node

## A [State] is a piece of logic that only runs when it is active.
## If this node is not a child of a State, it will automatically call enter() when it is added to the scene tree.
## It will call the update and physics_update functions every frame while it is active.
## And it will automatically call exit() when it is removed from the scene tree.
## See [ConcurrentState] and [SelectState] for states that control when other states are active.

## Emitted when the state is entered.
signal enabled()
## Emitted when the state is exited.
signal disabled()
## Emitted when a transition is requested.
signal transition_requested(state: State)

@export var is_enabled: bool = true : set = _set_enabled

func _set_enabled(value: bool):
	if value:
		process_mode = PROCESS_MODE_INHERIT
		if is_active(): enabled.emit()
	else:
		process_mode = PROCESS_MODE_DISABLED
		disabled.emit()
	is_enabled = value

func is_active() -> bool:
	return is_enabled and process_mode != PROCESS_MODE_DISABLED

## Call this function to request a transition to another state.
## This will emit the [signal State.transition_requested] signal.
func request_transition():
	transition_requested.emit(self)

func _notification(what):
	if what == NOTIFICATION_ENTER_TREE:
		_set_enabled(is_enabled)
	
	if what == NOTIFICATION_UNPAUSED:
		if is_active():
			enabled.emit()
	
	if what == NOTIFICATION_EXIT_TREE or what == NOTIFICATION_PAUSED:
		if not is_active():
			disabled.emit()
