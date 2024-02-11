class_name ConcurrentState extends AutoTransitionState

## A concurrent state is a state that runs the update and physics_update functions of all its children concurrently.
## It is useful for running multiple states at the same time.

## Calls the enter function of all children that are states.
func enter():
	for child in get_children():
		if child is State:
			child._internal_enter()

## Calls the exit function of all children that are states.
func exit():
	for child in get_children():
		if child is State:
			child._internal_exit()

## Calls the update function of all children that are states.
func update(delta):
	for child in get_children():
		if child is State:
			child._internal_update(delta)

## Calls the physics_update function of all children that are states.
func physics_update(delta):
	for child in get_children():
		if child is State:
			child._internal_physics_update(delta)
