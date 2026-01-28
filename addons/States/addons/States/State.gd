@icon("./state_icon.png")
class_name State extends Node

## A [State] is a piece of logic that only runs when it is active.

class TransitionEvent extends RefCounted:
	var initiator: Node
	var active_state: State
	var is_accepted: bool = false

	@warning_ignore("shadowed_variable")
	func _init(state:State):
		self.initiator = state
		self.active_state = state

	func accept():
		is_accepted = true

## Emitted when the state is enabled.
signal enabled()
## Emitted when the state is disabled.
signal disabled()
## Emitted when a transition is requested.
signal transition_requested(event: TransitionEvent)

## If this state is currently enabled or not
@export var is_enabled: bool = true:
	set(value):
		is_enabled = value
		if _enable_state_changing:
			# We can't change the process_mode while in the middle of the node being enabled/disabled
			set_deferred("process_mode", PROCESS_MODE_INHERIT if value else PROCESS_MODE_DISABLED)
		else:
			process_mode = Node.PROCESS_MODE_INHERIT if value else PROCESS_MODE_DISABLED
	get:
		return is_inside_tree() and can_process()

var _enable_state_changing: bool = false

## Call this function to request a transition, what that means depends on the parent state.
## This bubbles up until it reaches a state that accepts the transition.
func request_transition() -> void:
	assert(not _enable_state_changing, "Currently enabling/disabling this state, transition cannot be requested.")
	if get_parent() is State:
		#push_warning(get_path(), " REQUESTED TRANSITION")
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
	# There is a case where a node can be "enabled" but the tree is paused when ready
	# If this node isn't disabled we can assume it might be activated eventually
	if what == NOTIFICATION_READY and get_tree().paused:
		if process_mode != PROCESS_MODE_DISABLED:
			enabled.emit()
		else:
			disabled.emit()
		
	if (what == NOTIFICATION_ENABLED or what == NOTIFICATION_DISABLED):
		_enable_state_changing = true
		if is_enabled:
			#push_warning(get_path(), " ENABLED")
			enabled.emit()
		else:
			#push_warning(get_path() if is_inside_tree() else name, " DISABLED")
			disabled.emit()
		_enable_state_changing = false
