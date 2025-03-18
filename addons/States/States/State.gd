@icon("./state_icon.png")
class_name State extends Node

## A [State] is a piece of logic that only runs when it is active.
## If this node is not a child of a State, it will automatically call enter() when it is added to the scene tree.
## It will call the update and physics_update functions every frame while it is active.
## And it will automatically call exit() when it is removed from the scene tree.
## See [ConcurrentState] and [SelectState] for states that control when other states are active.


class TransitionEvent extends RefCounted:
	var initiating_state: State
	var active_state: State
	var is_accepted: bool = false

	@warning_ignore("shadowed_variable")
	func _init(initiating_state: State = null):
		self.initiating_state = initiating_state
		self.active_state = initiating_state

	func accept():
		is_accepted = true

## Emitted when the state is entered.
signal enabled()
## Emitted when the state is exited.
signal disabled()
## Emitted when a transition is requested.
signal transition_requested(event: TransitionEvent)

@export var is_enabled: bool = true: set = _set_enabled

var _process_mode_update_queued: bool = false

func _set_enabled(value):
	if is_enabled == value:
		return
	is_enabled = value
	if is_inside_tree():
		if not is_enabled:
			process_mode = PROCESS_MODE_DISABLED
		if not _process_mode_update_queued:
			_process_mode_update_queued = true
			_update_process_mode()

func _update_process_mode():
	await get_tree().process_frame
	process_mode = PROCESS_MODE_INHERIT if is_enabled else PROCESS_MODE_DISABLED
	_process_mode_update_queued = false

func is_active() -> bool:
	return is_enabled and can_process()

## Call this function to request a transition, what that means depends on the parent state.
## This bubbles up until it reaches a state that accepts the transition.
func request_transition() -> void:
	if get_parent() is State:
		var event = TransitionEvent.new(self)
		get_parent()._request_transition(event)

func _request_transition(event: TransitionEvent):
	transition_requested.emit(event)
	if not event.is_accepted and get_parent() is State:
		event.active_state = self
		get_parent()._request_transition(event)
	elif not event.is_accepted:
		# No parent to accept the transition, push a warning
		push_warning("Unhandled transition request starting from \"%s\"" % event.initiating_state.get_path())

func _notification(what):
	if (what == NOTIFICATION_ENTER_TREE or what == NOTIFICATION_UNPAUSED) and is_active():
		#prints("ENABLED", get_path())
		enabled.emit()
	if (what == NOTIFICATION_PAUSED or what == NOTIFICATION_EXIT_TREE):
		#prints("DISABLED", get_path())
		disabled.emit()
