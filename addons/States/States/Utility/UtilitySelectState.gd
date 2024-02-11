@icon("./utility_state_icon.png")
class_name UtilitySelectState extends SelectState

## The utility select state selects a child state based on the utility of the child [UtilityState].
## If the child is not a [UtilityState] but still a [State], it's utility is considered to be 0. This can be used to have a fallback state.

signal completed()

## How many of the top children should be considered for selection.
@export var select_from_top:int = 1
@export var continue_after_completion:bool = true

## The seed used for random selection. If the seed is -1, the seed is randomized.
@warning_ignore("shadowed_global_identifier") 
@export_range(-1, 0, 1, "or_greater") var seed:int = -1 :
	set(value):
		if value != seed:
			seed = value
			if seed >= 0:
				rng.seed = seed

## The bias towards children with lower index. A value of 0 means no bias, a value of 1 means maximum bias.
@export_range(0, 1, 0.01) var children_order_bias:float = 1.0

var rng:RandomNumberGenerator = RandomNumberGenerator.new()

func _on_child_completed():
	emit_signal("completed")
	if continue_after_completion:
		_internal_select_best_child()

func _on_child_added(child):
	super._on_child_added(child)
	if child is UtilityState:
		child.completed.connect(_on_child_completed)

func _on_child_transition(new_state:State):
	if new_state == null:
		_internal_select_best_child()
	else:
		super._on_child_transition(new_state)

func _internal_select_best_child():
	var queue = PriorityQueue.new(true) # max heap
	
	var child_bias = remap(1.0 / float(get_child_count()), 0.0, 1.0, 1.0, 0.999)
	for child in get_children():
		if not child is State:
			continue

		var utility = 0.0
		if child is UtilityState:
			if child.should_consider():
				utility = child._internal_get_utility()
			else:
				continue

		if not is_finite(utility):
			# if the utility is Infinity we can immediately select the child
			_on_child_transition(child)
			return
		
		utility *= child_bias

		# bias towards children with lower index
		if children_order_bias > 0.0:
			var index_weight = remap((float(child.get_index()) / float(get_child_count())), 0.0, 1.0, 1.0, 0.99)
			utility = lerp(utility, utility * index_weight, children_order_bias)
		
		queue.push(utility, child)
	
	if queue.is_empty():
		return
	
	var select_count = min(select_from_top, queue.size())
	if select_count == 1:
		_on_child_transition(queue.pop())
		return

	var top:Array = []
	for i in select_count:
		top.append(queue.pop())

	if not top.is_empty():
		if seed == -1:
			rng.randomize()
		var best_child = rng.randi_range(0, top.size() - 1)
		_on_child_transition(top[best_child])

## Selects the best child state based on the utility of the children.
## and calls [State.enter] on the selected child.
func enter():
	if not current_state:
		_internal_select_best_child()
	super.enter()

## every update checks if a current_state is still selected. If not, it selects a new child state.
func update(delta):
	super.update(delta)
	if not current_state:
		_internal_select_best_child()
