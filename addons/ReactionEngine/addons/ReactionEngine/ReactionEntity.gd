class_name ReactionEntity extends Resource

@export var extra_state: Array[Variant] = []

func get_rules(trigger: ReactionTrigger) -> Array[ReactionRule]:
	var result: Array[ReactionRule] = []
	for state in extra_state:
		if state is Dictionary and state.has("get_rules"):
			var f = state["get_rules"]
			if f is Callable:
				var extra_rules = f.call(trigger)
				if extra_rules is Array:
					for rule in extra_rules:
						if rule is ReactionRule:
							result.append(rule)
		elif state is Object and state.has_method("get_rules"):
			var extra_rules = state.get_rules(trigger)
			if extra_rules is Array:
				for rule in extra_rules:
					if rule is ReactionRule:
						result.append(rule)
	return result

func _get(property: StringName) -> Variant:
	for state in extra_state:
		if state is Dictionary:
			if state.has(property):
				return state[property]
		elif state is Object and property in state:
			return state.get(property)
	return null

func _set(property: StringName, value: Variant) -> bool:
	for state in extra_state:
		if state is Dictionary:
			if state.has(property):
				state[property] = value
				return true
		elif state is Object and property in state:
			state.set(property, value)
			return true
	return false
