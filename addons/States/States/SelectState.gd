class_name SelectState extends State

## A select state is a state that can only have one child active at a time.
## Children of select states should use the [signal State.transition_requested] signal to request that they become active using the [method State.request_transition] method.
## When a child requests a transition, the select state will call the [method State.exit] method of the current state, if there is one, and then call the [method State.enter] method of the new state.

signal active_state_changed(state: State)

@export var active_state: State

func _child_entered_tree(child):
	if child is State:
		child.is_enabled = active_state == child

func _on_transition_requested(event: TransitionEvent):
	if not event.active_state.get_parent() == self:
		push_error("Transition requested from a state that is not a child of this SelectState: ", event.active_state.get_path(), " in ", get_path())
		return
	event.accept()
	_select_new_state(event.active_state)

func _select_new_state(new_state: State):
	if active_state:
		active_state.is_enabled = false

	if new_state == active_state:
		if active_state:
			active_state.is_enabled = true
		return
	
	active_state = new_state

	if active_state:
		active_state.is_enabled = true
	
	active_state_changed.emit(active_state)

## Calls the enter method of the current state.
func _set_enabled(value):
	for child in get_children():
		if child is State:
			child.is_enabled = false
	if active_state:
		active_state.is_enabled = value
	super._set_enabled(value)

func _notification(what):
	if what == NOTIFICATION_ENTER_TREE:
		child_entered_tree.connect(_child_entered_tree)
		transition_requested.connect(_on_transition_requested)
	elif what == NOTIFICATION_EXIT_TREE:
		child_entered_tree.disconnect(_child_entered_tree)
		transition_requested.disconnect(_on_transition_requested)
	elif what == NOTIFICATION_READY and not active_state:
		push_warning(get_path(), " Has no active state selected")
