@icon("./state_icon.png")
extends Node
class_name State

## A [State] is a piece of logic that only runs when it is active.
## See [ConcurrentState] and [SelectState] for states that control when other states are active.

## Emitted when the state is entered.
signal entered()
## Emitted when the state is exited.
signal exited()
## Emitted when a transition is requested.
signal transition_requested()

func _enter_tree():
	# If this state is the root of the tree, then it should be active by default.
	if get_parent() is State:
		set_process(false)
		set_physics_process(false)
	else:
		enter()

func _exit_tree():
	_internal_exit()

func _process(delta):
	_internal_update(delta)

func _physics_process(delta):
	_internal_physics_update(delta)

## Override this method to define behavior when entering the state.
func enter():
	pass

## Override this method to define behavior when exiting the state.
func exit():
	pass

## Override this method for state-specific per-frame logic.
## The [param delta] parameter represents the time since the last frame.
@warning_ignore("unused_parameter")
func update(delta):
	pass

## Override this method for state-specific physics-related updates.
## This is called every physics frame while the state is active.
## The [param delta] parameter represents the time since the last physics frame.
@warning_ignore("unused_parameter")
func physics_update(delta):
	pass

## Call this function to request a transition to another state.
## This will emit the [signal State.transition_requested] signal.
func request_transition():
	emit_signal("transition_requested")

func _internal_enter():
	enter()
	emit_signal("entered")

func _internal_exit():
	exit()
	emit_signal("exited")

func _internal_update(delta):
	update(delta)

func _internal_physics_update(delta):
	physics_update(delta)
