@icon("./utility_state_icon.png")
class_name UtilityState extends State

## This is a [State] that can be used in a [UtilitySelectState] to select the most appropriate state to transition to.

## The weight of this state in the utility calculation, higher weights are more likely to be selected
@export var weight:float = 1.0

## The time this state was entered
var enter_time:float = 0.0 

## Override this function to tell the [UtilitySelectState] if this state should be considered
func should_consider() -> bool:
	return false

## Override this function to add your own considerations
## See [method UtilityState.consider] for an example
func get_utility() -> float:
	return weight

## consider is a helper function to calculate the utility of this state.
## example:
## [codeblock]
## func get_utility(): 
##  return (
##		consider(remap(distance, min_distance, max_distance, 0.0, 1.0), distance_weight) *
##  	consider(wrapf(something_else, 0.0, 1.0), some_weight)
##  )
##
## func update(delta):
##  # do stuff when selected
## 
## [/codeblock]
@warning_ignore("shadowed_variable")
func consider(value:float, weight:float = 1.0) -> float:
	var consideration = value + (1.0 - value) * value
	return lerp(consideration, 1.0, 1.0 - weight)

## Returns the normalized time since some time in seconds.
func get_elapsed_time_seconds(time:float) -> float:
	var now_seconds = Time.get_ticks_msec() / 1000.0
	var delta = ( now_seconds - time)
	return delta

## Returns the normalized time since this state was entered.
func get_elapsed_time_since_entered_seconds() -> float:
	return get_elapsed_time_seconds(enter_time)

## Returns the normalized time since some time in seconds.
func get_progress_towards_max_duration(time:float, max_seconds:float) -> float:
	return get_elapsed_time_seconds(time) / max_seconds

## Returns the normalized time since this state was entered.
func get_progress_towards_max_duration_since_entered(max_seconds:float) -> float:
	return get_progress_towards_max_duration(enter_time, max_seconds)

## This normalizes a value between 0 and 1 nonlineraly
## Useful when very large or small values are not meaningful
func inverse_normalized(value:float) -> float:
	if is_inf(value) or is_nan(value) or value == 0.0:
		return 0.0
	return 1.0 - (1.0 / value)

## This normalizes a value between 0 and 1 lineraly
func normalized(value:float, minimum:float, maximum:float) -> float:
	if (
		is_inf(value) or is_inf(minimum) or is_inf(maximum) or 
		is_nan(value) or is_nan(minimum) or is_nan(maximum) or 
		maximum - minimum == 0.0
	):
		return 0.0
	return (value - minimum) / (maximum - minimum)

func _notification(what):
	if what == NOTIFICATION_READY or what == NOTIFICATION_UNPAUSED:
		if is_enabled:
			enter_time = Time.get_ticks_msec() / 1000.0