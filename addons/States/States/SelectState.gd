class_name SelectState extends AutoTransitionState

## A select state is a state that can only have one child active at a time.
## Children of select states should use the [signal State.transition_requested] signal to request that they become active using the [method State.request_transition] method.
## When a child requests a transition, the select state will call the [method State.exit] method of the current state, if there is one, and then call the [method State.enter] method of the new state.

@export var current_state:State

func _enter_tree():
	child_entered_tree.connect(_on_child_added)

func _exit_tree():
	child_entered_tree.disconnect(_on_child_added)

func _on_child_added(child):
	if child is State:
		if not child.transition_requested.is_connected(_on_child_transition):
			child.transition_requested.connect(_on_child_transition)

func _on_child_transition(new_state:State):
	if new_state == current_state:
		return

	if current_state:
		current_state._internal_exit()
	
	current_state = new_state
	if current_state:
		current_state._internal_enter()

## Calls the enter method of the current state.
func enter():
	if current_state:
		if current_state.get_parent() != self:
			current_state = null
			push_error("SelectState: current_state is not a child of this node")
			return
		current_state._internal_enter()

## Calls the exit method of the current state.
func exit():
	if current_state:
		current_state._internal_exit()
		current_state = null

## Calls the update method of the current state.
func update(delta):
	if current_state:
		current_state._internal_update(delta)

## Calls the physics_update method of the current state.
func physics_update(delta):
	if current_state:
		current_state._internal_physics_update(delta)
