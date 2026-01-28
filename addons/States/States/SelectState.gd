class_name SelectState extends State

## A select state is a state that can only have one child active at a time.
## Children of select states should use the [method State.request_transition] to request that they become active.

## Emitted when the active state changes
signal active_state_changed()

## The currently active state
@export var active_state: State

func _child_entered_tree(child):
	if child is State:
		child.is_enabled = child == active_state

func _on_transition_requested(event: TransitionEvent):
	if not event.active_state.get_parent() == self:
		push_error("Transition requested from a state that is not a child of this SelectState: ", event.active_state.get_path(), " in ", get_path())
		return
	event.accept()
	_select_new_state(event.active_state)

func _select_new_state(new_state: State):
	if _enable_state_changing:
		# We're in the middle of being enabled, change the active state at the end of the frame
		_select_new_state.call_deferred(new_state)
		return
	if new_state == active_state:
		if active_state and not active_state.is_enabled:
			active_state.is_enabled = true
		return
	if active_state:
		active_state.is_enabled = false
	active_state = new_state
	if active_state:
		active_state.is_enabled = true
	active_state_changed.emit()

func _notification(what):
	if what == NOTIFICATION_ENTER_TREE:
		child_entered_tree.connect(_child_entered_tree)
		transition_requested.connect(_on_transition_requested)
	elif what == NOTIFICATION_EXIT_TREE:
		child_entered_tree.disconnect(_child_entered_tree)
		transition_requested.disconnect(_on_transition_requested)
	elif what == NOTIFICATION_READY and not active_state:
		push_warning(get_path(), " Has no active state selected")
