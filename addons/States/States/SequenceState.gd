class_name SequenceState extends SelectState

## A sequence state is a state that can only have one child active at a time.
## Active children of sequence states should use the [signal State.transition_requested] signal to make the next child of this node the active state.

func _on_transition_requested(event: TransitionEvent) -> void:
	if active_state == null:
		# If there is no current state, the requesting state is the new current state
		super._on_transition_requested(event)
		return
	
	# If the requesting state is not the current state, ignore the request
	if active_state != event.active_state:
		event.accept() # Stop the event from bubbling up
		return
	
	var new_state: State = null
	var count = get_child_count()
	var index = active_state.get_index() if active_state else -1
	
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

	event.active_state = new_state
	super._on_transition_requested(event)