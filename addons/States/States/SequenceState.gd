class_name SequenceState extends SelectState

## A sequence state is a state that can only have one child active at a time.
## Active children of sequence states should use the [signal State.transition_requested] signal to make the next child of this node the active state.

func _on_child_transition(requesting_state:State):
	if current_state == null:
		# If there is no current state, the requesting state is the new current state
		super._on_child_transition(requesting_state)
		return
	
	if current_state != requesting_state:
		# If the requesting state is not the current state, ignore the request
		return
	
	var new_state:State = null
	var count = get_child_count()
	var index = current_state.get_index() if current_state else -1
	
	# Find the next state in the list of children
	var start_index = index
	while true:
		index += 1
		if index >= count:
			index = 0
		var child = get_child(index)
		if child is State:
			new_state = child
			break
		if index == start_index:
			break

	super._on_child_transition(new_state)
