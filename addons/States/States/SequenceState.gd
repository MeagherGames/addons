class_name SequenceState extends SelectState

## Sequential state machine that advances through child states in order, and will wrap around.
## The [member SelectState.active_state] can request transition to advance to the next state.
## If a state that is not currently active calls [method State.request_transition] it will become the [member SelectState.active_state]

## Transition to the next child state.
func advance_to_next_state():
	var start_index = active_state.get_index() + 1 if active_state else -1
	var next_state = _find_next_state(start_index)
	if next_state:
		_select_new_state(next_state)
	else:
		push_error("No valid next state found in ", get_path())

## Resets sequence to the first available child state
func reset_to_first_state() -> void:
	if get_child_count() == 0:
		return
	var first_state = _find_next_state(0)
	if first_state:
		_select_new_state(first_state)
	else:
		push_error("No valid state found to reset to in ", get_path())

# Finds the next valid State child after the given index with wraparound
func _find_next_state(start_index: int) -> State:
	var count = get_child_count()
	var index = start_index
	
	# Linear search with wraparound to find next State child
	while true:
		if index >= count:
			index = 0 # Wraparound to beginning
		var child = get_child(index)
		if child is State:
			return child
		index += 1
		if index == start_index:
			break # Full cycle completed, no valid state found
	
	return null

# Handles transition requests with support for both sequential and out-of-order transitions
func _on_transition_requested(event: TransitionEvent) -> void:
	if active_state == null or event.active_state != active_state:
		# Allow out-of-sequence transitions from external sources
		super._on_transition_requested(event)
		return
	
	# Sequential transition: advance to next state in order
	var index = active_state.get_index() + 1 if active_state else 0
	event.active_state = _find_next_state(index)
	super._on_transition_requested(event)
