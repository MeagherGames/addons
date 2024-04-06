class_name SelectState extends State

## A select state is a state that can only have one child active at a time.
## Children of select states should use the [signal State.transition_requested] signal to request that they become active using the [method State.request_transition] method.
## When a child requests a transition, the select state will call the [method State.exit] method of the current state, if there is one, and then call the [method State.enter] method of the new state.

@export var current_state:State

func _on_child_added(child):
	if child is State:
		if not child.transition_requested.is_connected(_on_child_transition):
			child.transition_requested.connect(_on_child_transition)

func _on_child_transition(new_state:State):
	if new_state == current_state:
		return

	if current_state:
		current_state.is_enabled = false
	
	current_state = new_state
	if current_state:
		current_state.is_enabled = true

## Calls the enter method of the current state.
func _set_enabled(value):
	for child in get_children():
		if child is State:
			child.is_enabled = false
	if current_state:
		current_state.is_enabled = value
	super._set_enabled(value)

func _notification(what):
	if what == NOTIFICATION_ENTER_TREE:
		child_entered_tree.connect(_on_child_added)
	elif what == NOTIFICATION_EXIT_TREE:
		child_entered_tree.disconnect(_on_child_added)