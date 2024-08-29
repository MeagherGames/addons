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

@export var is_enabled: bool = true : set = _set_enabled, get = _get_enabled

func _set_enabled(value: bool):
	is_enabled = value
	process_mode = PROCESS_MODE_PAUSABLE if value else PROCESS_MODE_DISABLED

func _get_enabled():
	if is_inside_tree():
		return process_mode != PROCESS_MODE_DISABLED and get_tree().paused == false
	return is_enabled

func _enabled():
	pass

func _disabled():
	pass


## Call this function to request a transition to another state.
## This will emit the [signal State.transition_requested] signal.
func request_transition():
	transition_requested.emit(self)

func _notification(what):
	if what == NOTIFICATION_READY:
		_set_enabled(is_enabled)
	
	if  what == NOTIFICATION_ENTER_TREE or what == NOTIFICATION_UNPAUSED:
		if is_enabled:
			_enabled()
			enabled.emit()
	elif what == NOTIFICATION_EXIT_TREE or what == NOTIFICATION_PAUSED:
		if not is_enabled:
			_disabled()
			disabled.emit()
