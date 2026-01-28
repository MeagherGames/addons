class_name Utility extends Object

## This is a set of utility functions that are useful for AI and other systems

func _init():
	push_error("Utility is a static class and should not be instanced.")

## Multiply considerations together to get utility
static func consider(value:float, weight:float) -> float:
	var consideration = value + (1.0 - value) * value
	return lerp(consideration, 1.0, 1.0 - weight)

## This normalizes a value between 0 and 1 nonlineraly
## Useful when very large or small values are not meaningful
static func inverse_normalized(value:float) -> float:
	if is_inf(value) or is_nan(value) or value == 0.0:
		return 0.0
	return 1.0 - (1.0 / value)

## This normalizes a value between 0 and 1 lineraly
static func normalized(value:float, minimum:float, maximum:float) -> float:
	if (
		is_inf(value) or is_inf(minimum) or is_inf(maximum) or 
		is_nan(value) or is_nan(minimum) or is_nan(maximum) or 
		maximum - minimum == 0.0
	):
		return 0.0
	return (value - minimum) / (maximum - minimum)