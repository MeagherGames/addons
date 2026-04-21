class_name Token extends Resource

## A Token is a status effect that can be applied to a [ReactionEntity].
## It can have modifiers that change how the token behaves, and rules that trigger reactions when certain conditions are met.

@export var max_count: int = 0
@export var modifiers: Array[TokenModifier] = []
@export var rules: Array[ReactionRule] = []

func on_added(ctx: ReactionContext) -> void:
	for modifier in modifiers:
		modifier._added(ctx)


func on_removed(ctx: ReactionContext) -> void:
	for modifier in modifiers:
		modifier._removed(ctx)


func get_rules(trigger: ReactionTrigger) -> Array[ReactionRule]:
	var result: Array[ReactionRule] = []
	for rule in rules:
		if rule.trigger == trigger:
			result.append(rule)
	return result
