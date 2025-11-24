class_name UtilityGroupState extends UtilityState

## A UtilityGroupState is a utility state that can have multiple child [UtilityState]s or [UtilitySelectorState]s.

## Determines if the state should be considered based on its child states.
func should_consider() -> bool:
	for child in get_children():
		if (child is UtilityState or child is UtilitySelectState) and not await child.should_consider():
			return false
	return true

## Calculates the combined utility of all child states.
func get_utility() -> float:
	var total_child_weight: float = 0.0
	for child in get_children():
		if child is UtilityState or child is UtilitySelectState:
			total_child_weight += child.weight
	
	var utility: float = 1.0
	for child in get_children():
		if child is UtilityState or child is UtilitySelectState:
			utility *= lerp(
				1.0,
				clampf(await child.get_utility(), 0, 1),
				child.weight / total_child_weight
			)
			
	return utility
