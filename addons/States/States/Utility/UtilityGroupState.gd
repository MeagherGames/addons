class_name UtilityGroupState extends UtilityState

## A UtilityGroupState is a utility state that can have multiple child [UtilityState]s or [UtilitySelectorState]s.

func should_consider() -> bool:
	for child in get_children():
		if (child is UtilityState or child is UtilitySelectState) and not child.should_consider():
			return false
	return true

func get_utility() -> float:
	var total_child_weight: float = 0.0
	for child in get_children():
		if child is UtilityState or child is UtilitySelectState:
			total_child_weight += child.weight
	
	var utility: float = 1.0
	for child in get_children():
		if child is UtilityState or child is UtilitySelectState:
			var child_factor: float = child.weight / total_child_weight
			utility *= consider(child.get_utility(), child.weight * child_factor)
			
	return utility
