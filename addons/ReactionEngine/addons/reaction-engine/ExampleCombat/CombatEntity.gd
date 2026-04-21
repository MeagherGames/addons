class_name CombatEntity extends ReactionEntity

@export var max_health:int = 100
@export var health:int = 100 :
	set(value):
		health = clamp(value, 0, max_health)
@export var tokens: Dictionary[Token, int] = {}

func is_dead() -> bool:
	return health <= 0

func get_rules(trigger: ReactionTrigger) -> Array[ReactionRule]:
	var result: Array[ReactionRule] = []
	for token in tokens:
		result.append_array(token.get_rules(trigger))
	return result
