@icon("./utility_state_icon.png")
class_name UtilitySelectState extends SelectState

## The UtilitySelectState selects a child state based on the utility, see [UtilityState].
## Children can return [constant @GDScript.INF] as their utility to be immediately selected
## If the child is not a [UtilityState] but still a [State], it's utility is considered to be 0.

const _EPSILON = 0.01

## The weight of this state in the utility calculation, higher weights are more likely to be selected.
@export var weight: float = 1.0
## How many of the top children should be considered for selection.
@export_range(1, 1, 1, "or_greater") var select_from_top: int = 1

## The bias towards children based on order in the tree. A value of 0 means no bias, a value of 1 means child order matters when making a decision.
@export_range(0, 1, 0.01) var children_order_bias: float = 1.0

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

@warning_ignore("unused_parameter")
func _on_transition_requested(event: TransitionEvent):
	if (
		event.active_state is UtilityState or
		event.active_state is UtilitySelectState
	):
		var parent = get_parent()
		if not (parent is UtilityState or parent is UtilitySelectState):
			# We are the top level UtilitySelectState
			# We should accept the transition
			event.accept()
		_select_best_state()
	else:
		super._on_transition_requested(event)

func _select_best_state():
	if get_child_count() == 0:
		return
	
	var queue: PriorityQueue = PriorityQueue.new(true) # max heap
	
	if active_state:
		active_state.is_enabled = false

	# Calculate relative weights for utility normalization
	var total_child_weight: float = 0.0
	var children_to_consider: Array = []
	for child in get_children():
		if not (child is UtilityState or child is UtilitySelectState) or not child.should_consider():
			continue
		total_child_weight += child.weight
		children_to_consider.append(child)
	
	# Build priority queue of states with calculated utilities
	for child in children_to_consider:
		var child_factor = 1.0
		if total_child_weight > 0.0:
			child_factor = child.weight / total_child_weight

		var utility = child.get_utility() * child_factor
		if not is_finite(utility):
			# Infinite utility means immediate selection (emergency states)
			_select_new_state(child)
			return

		# Apply index bias to favor children when utilities are close
		if children_order_bias > 0.0:
			var index_weight = remap((float(child.get_index()) / float(get_child_count())), 0.0, 1.0, 1.0, 1.0 - _EPSILON)
			utility = lerp(utility, utility * index_weight, children_order_bias)
		
		queue.push(utility, child)
	
	if queue.is_empty():
		_select_new_state(null)
		return
	
	# Select from top N candidates using weighted random selection
	var select_count = min(select_from_top, queue.size())
	if select_count == 1:
		_select_new_state(queue.pop())
		return

	# Weighted random selection from top candidates
	var top: Array = []
	var weights: Array[float]
	var total_weight: float = 0.0
	for i in select_count:
		var w = queue.peek_priority()
		total_weight += w
		weights.append(w)
		top.append(queue.pop())
	
	# Roulette wheel selection based on utility weights
	var random_value = _rng.randf() * total_weight
	var best_child = 0
	for i in select_count:
		random_value -= weights[i]
		if random_value <= 0.0:
			best_child = i
			break
	_select_new_state(top[best_child])

## Returns true if the active state should be considered for selection.
func should_consider() -> bool:
	if not active_state or not active_state.should_consider():
		_select_best_state()
	if not active_state:
		return false
	return active_state.should_consider()

## Returns 1.0 as the utility of this state.
## This is to allow nested UtilitySelectSates.
func get_utility() -> float:
	return 1.0

func _notification(what: int) -> void:
	if what == NOTIFICATION_ENTER_TREE:
		_rng.seed = randi()
