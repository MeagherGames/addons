@icon("./utility_state_icon.png")
class_name UtilitySelectState extends SelectState

## The utility select state selects a child state based on the utility of the child [UtilityState].
## If the child is not a [UtilityState] but still a [State], it's utility is considered to be 0. This can be used to have a fallback state.

const EPSILON = 0.01

## The weight of this state in the utility calculation, higher weights are more likely to be selected
@export var weight: float = 1.0
## How many of the top children should be considered for selection.
@export_range(1, 1, 1, "or_greater") var select_from_top: int = 1

## The bias towards children with lower index. A value of 0 means no bias, a value of 1 means maximum bias.
@export_range(0, 1, 0.01) var children_order_bias: float = 1.0

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _select_best_state_queued: bool = false

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
		_queue_select_best_state()
	else:
		super._on_transition_requested(event)

func _queue_select_best_state():
	if _select_best_state_queued:
		return
	_select_best_state_queued = true
	await _select_best_state()
	_select_best_state_queued = false

func _select_best_state():
	if get_child_count() == 0:
		return

	if not Engine.is_in_physics_frame():
		await get_tree().physics_frame
	
	var queue: PriorityQueue = PriorityQueue.new(true) # max heap
	
	if active_state:
		active_state.is_enabled = false
	
	for child in get_children():
		if not (
			(child is UtilityState or child is UtilitySelectState) and
			await child.should_consider()
		):
			continue

		var utility = (await child.get_utility()) * child.weight
		if not is_finite(utility):
			# if the utility is Infinity we can immediately select the child
			_select_new_state(child)
			return

		# bias towards children with lower index
		if children_order_bias > 0.0:
			var index_weight = remap((float(child.get_index()) / float(get_child_count())), 0.0, 1.0, 1.0, 1.0 - EPSILON)
			utility = lerp(utility, utility * index_weight, children_order_bias)
		
		queue.push(utility, child)
	
	if queue.is_empty():
		_select_new_state(null)
		return
	
	var select_count = min(select_from_top, queue.size())
	if select_count == 1:
		_select_new_state(queue.pop())
		return

	var top: Array = []
	var weights: Array[float]
	var total_weight: float = 0.0
	for i in select_count:
		var w = queue.peek_priority()
		total_weight += w
		weights.append(w)
		top.append(queue.pop())
	
	var random_value = rng.randf() * total_weight
	var best_child = 0
	for i in select_count:
		random_value -= weights[i]
		if random_value <= 0.0:
			best_child = i
			break
	_select_new_state(top[best_child])

## Returns true if the active state should be considered for selection.
func should_consider() -> bool:
	var should_consider_current_active_state: bool = false
	if active_state:
		should_consider_current_active_state = await active_state.should_consider()
	if not should_consider_current_active_state:
		await _queue_select_best_state()
	if not active_state:
		return false
	return await active_state.should_consider()

## Returns 1.0 as the utility of this state.
func get_utility() -> float:
	return 1.0

func _notification(what: int) -> void:
	if what == NOTIFICATION_ENTER_TREE:
		rng.seed = randi()
