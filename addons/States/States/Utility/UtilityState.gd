@icon("./utility_state_icon.png")
class_name UtilityState extends State

## This is a [State] that can be used in a [UtilitySelectState] to select the most appropriate state to transition to.

## Emitted when the state is completed and the [UtilitySelectState] should transition to the next best state
signal completed()

## The weight of this state in the utility calculation, higher weights are more likely to be selected
@export var weight:float = 1.0

## The time this state was entered
var enter_time:float = 0.0

class Consideration extends RefCounted:
	## A simple struct to hold a value and weight for a consideration

	var value:float = 0.0
	var weight:float = 1.0

	@warning_ignore("shadowed_variable")
	func _init(value:float, weight:float = 1.0):
		self.value = value
		self.weight = weight

func _internal_get_utility() -> float:
	
	var considerations = get_considerations()
	if considerations.size() == 0:
		return weight

	var compensation:float = normal_inverse(considerations.size())
	var result = weight
	
	for consideration in considerations:
		var value = consideration.value
		var consideration_weight = consideration.weight

		var modification = (1.0 - consideration.value) * compensation

		value += modification * value

		result *= lerp(value, 1.0, 1.0 - consideration_weight)
	
	return result

func _internal_enter() -> void:
	enter_time = Time.get_ticks_msec() / 1000.0
	super._internal_enter()


## Override this function to tell the [UtilitySelectState] if this state should be considered
func should_consider() -> bool:
	return false

## Override this function to add your own considerations
## See [method UtilityState.consider] for an example
func get_considerations() -> Array[Consideration]:
	return []

## Add a consideration to be used in the utility calculation
## example:
## [codeblock]
## func get_considerations(): 
##  return [
##		consider(remap(distance, min_distance, max_distance, 0.0, 1.0), distance_weight),
##  	consider(wrapf(something_else, 0.0, 1.0), some_weight)
##  ]
##
## func update(delta):
##  # do stuff when selected
## 
## [/codeblock]
@warning_ignore("shadowed_variable")
func consider(value:float, weight:float = 1.0) -> Consideration:
	var consideration = Consideration.new(value, weight)
	return consideration

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

## Returns the normalized inverse of some value.
## If the value is 0.0, inf or nan, 0.0 is returned.
## Otherwise 1.0 - (1.0 / value) is returned.
func normal_inverse(value:float) -> float:
	if is_inf(value) or is_nan(value) or value == 0.0:
		return 0.0
	return 1.0 - (1.0 / value)

## Let the [UtilitySelectState] know that this state is completed and it should transition to the next best state
func complete():
	emit_signal("completed")
