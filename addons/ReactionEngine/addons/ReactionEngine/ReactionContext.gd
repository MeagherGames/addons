class_name ReactionContext extends RefCounted

# nested types are not supported, so this class is defined above
var _entity_trigger_data: Dictionary[ReactionEntity, Dictionary] = {}
var _action_stack: Array[ReactionAction] = []
var action: ReactionAction:
	get:
		if _action_stack.size() == 0:
			return null
		return _action_stack.back()
var extra_state: Array[Variant] = []

@warning_ignore("shadowed_variable")
func trigger_action(action: ReactionAction) -> Variant:
	_action_stack.append(action)
	@warning_ignore("redundant_await")
	var result = await action._execute(self)
	_action_stack.pop_back()
	return result

func trigger_rules(entity: ReactionEntity, trigger: ReactionTrigger) -> void:
	assert(entity != null, "Entity cannot be null when triggering rules.")
	assert(trigger != null, "Trigger cannot be null when triggering rules.")
	assert(action != null, "Current action cannot be null when triggering rules.")
	
	var rules: Array[ReactionRule] = entity.get_rules(trigger) + _get_rules(trigger)
	for rule in rules:
		# Rules have limits on how many times they can be triggered during a single combat encounter
		if _can_trigger_rule(entity, rule):
			_mark_rule_triggered(entity, rule)
			await rule.apply(self)


func _can_trigger_rule(entity: ReactionEntity, rule: ReactionRule) -> bool:
	var trigger_data: Dictionary = _entity_trigger_data.get(entity, null)
	if trigger_data == null:
		return true
	
	var rule_trigger_data: Dictionary = trigger_data.get(rule.trigger, null)
	if rule_trigger_data == null:
		return true

	var trigger_count = rule_trigger_data.get(rule, 0)
	if rule.trigger_limit > 0 and trigger_count >= rule.trigger_limit:
		return false
	
	return true

func _mark_rule_triggered(entity: ReactionEntity, rule: ReactionRule) -> void:
	var trigger_data: Dictionary = _entity_trigger_data.get(entity, null)
	if trigger_data == null:
		trigger_data = {}
		_entity_trigger_data[entity] = trigger_data
	
	var rule_trigger_data: Dictionary = trigger_data.get(rule.trigger, null)
	if rule_trigger_data == null:
		rule_trigger_data = {}
		trigger_data[rule.trigger] = rule_trigger_data
	
	var current_count: int = rule_trigger_data.get(rule, 0)
	rule_trigger_data[rule] = current_count + 1

func _get_rules(trigger: ReactionTrigger) -> Array[ReactionRule]:
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