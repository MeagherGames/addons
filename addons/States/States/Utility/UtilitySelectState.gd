@icon("./utility_state_icon.png")
class_name UtilitySelectState extends SelectState

## The utility select state selects a child state based on the utility of the child [UtilityState].
## If the child is not a [UtilityState] but still a [State], it's utility is considered to be 0. This can be used to have a fallback state.

const EPSILON = 0.01

enum UpdateMode {
	PROCESS,
	PHYSICS,
	MANUAL
}

## How many of the top children should be considered for selection.
@export var select_from_top: int = 1
@export var weight: float = 1.0

## The seed used for random selection. If the seed is -1, the seed is randomized.
@warning_ignore("shadowed_global_identifier")
@export_range(-1, 0, 1, "or_greater") var seed: int = -1:
	set(value):
		if value != seed:
			seed = value
			if seed >= 0:
				rng.seed = seed

## The bias towards children with lower index. A value of 0 means no bias, a value of 1 means maximum bias.
@export_range(0, 1, 0.01) var children_order_bias: float = 1.0
@export var update_mode: UpdateMode = UpdateMode.PROCESS:
	set(value):
		if value == UpdateMode.PROCESS:
			set_process(true)
			set_physics_process(false)
		elif value == UpdateMode.PHYSICS:
			set_process(false)
			set_physics_process(true)
		else:
			set_process(false)
			set_physics_process(false)

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var queue: PriorityQueue = PriorityQueue.new(true) # max heap

@warning_ignore("unused_parameter")
func _on_transition_requested(event: TransitionEvent):
	if (
		event.current_state is UtilityState or
		event.current_state is UtilitySelectState
	):
		event.accept()
		select_next_state()
		
		var parent = get_parent()
		if parent is UtilitySelectState or parent is UtilityState:
			request_transition()
	else:
		super._on_transition_requested(event)

func select_next_state():
	if get_child_count() == 0:
		return
	queue.clear()

	var transition_event = TransitionEvent.new(self)
	
	for child in get_children():
		if not child is State:
			continue

		var utility = 0.0 # regular states are considered to have 0 utility
		if child is UtilityState or child is UtilitySelectState:
			if child.should_consider():
				utility = child.get_utility() * child.weight
			else:
				continue

		if not is_finite(utility):
			# if the utility is Infinity we can immediately select the child
			transition_event.current_state = child
			super._on_transition_requested(transition_event)
			return


		# bias towards children with lower index
		if children_order_bias > 0.0:
			var index_weight = remap((float(child.get_index()) / float(get_child_count())), 0.0, 1.0, 1.0, 1.0 - EPSILON)
			utility = lerp(utility, utility * index_weight, children_order_bias)
		
		queue.push(utility, child)
	
	if queue.is_empty():
		return
	
	var select_count = min(select_from_top, queue.size())
	if select_count == 1:
		transition_event.current_state = queue.pop()
		super._on_transition_requested(transition_event)
		return

	var top: Array = []
	for i in select_count:
		top.append(queue.pop())

	if not top.is_empty():
		if seed == -1:
			rng.seed = randi()
		var best_child = rng.randi_range(0, top.size() - 1)
		transition_event.current_state = top[best_child]
		super._on_transition_requested(transition_event)

func _notification(what):
	if what == NOTIFICATION_READY:
		if not current_state:
			select_next_state()
		
	if (
		(what == NOTIFICATION_PROCESS and update_mode == UpdateMode.PROCESS) or
		(what == NOTIFICATION_PHYSICS_PROCESS and update_mode == UpdateMode.PHYSICS)
	):
		if not current_state:
			select_next_state()

func should_consider() -> bool:
	if not current_state:
		select_next_state()
		if not current_state:
			return false
	return current_state.should_consider()

func get_utility() -> float:
	if not current_state:
		select_next_state()
		if not current_state:
			return 0.0
	return current_state.get_utility() * current_state.weight