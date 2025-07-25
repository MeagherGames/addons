@icon("./utility_state_icon.png")
class_name UtilityState extends State

## This is a [State] that can be used in a [UtilitySelectState] to select the most appropriate state to transition to.

## The weight of this state in the utility calculation, higher weights are more likely to be selected
@export var weight: float = 1.0

## This is a helper function to determine if this state should be considered for selection.
## Override this function to tell the [UtilitySelectState] if this state should be considered
## returns true by default
func should_consider() -> bool:
	return true

## Override this function to calculate the utility of this state.
## The utility is a value between 0 and 1, where 0 is not useful and 1 is very useful.
## returns 1.0 by default
func get_utility() -> float:
	return 1.0

## Returns the current time in seconds.
func get_time() -> float:
	return Time.get_ticks_msec() / 1000.0

## Returns the relative time since some time in seconds.
func get_elapsed_time(time: float) -> float:
	var now_seconds = Time.get_ticks_msec() / 1000.0
	var delta = (now_seconds - time)
	return delta

## Returns the normalized time since some time in seconds.
func get_progress_towards_max_duration(time: float, max_seconds: float) -> float:
	return get_elapsed_time(time) / max_seconds

## This normalizes a value between 0 and 1 nonlineraly
## Useful when very large or small values are not meaningful
func inverse_normalized(value: float) -> float:
	if is_inf(value) or is_nan(value) or value == 0.0:
		return 0.0
	return 1.0 - (1.0 / value)

## This normalizes a value between 0 and 1 lineraly
func normalized(value: float, minimum: float, maximum: float) -> float:
	if (
		is_inf(value) or is_inf(minimum) or is_inf(maximum) or
		is_nan(value) or is_nan(minimum) or is_nan(maximum) or
		maximum - minimum == 0.0
	):
		return 0.0
	return (value - minimum) / (maximum - minimum)
