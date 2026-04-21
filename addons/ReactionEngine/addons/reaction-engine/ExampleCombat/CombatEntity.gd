class_name CombatEntity extends ReactionEntity

@export var max_health:int = 100
@export var health:int = 100
@export var tokens: Dictionary[Token, int] = {}
@export var is_dead:bool = false

func get_rules(trigger: ReactionTrigger) -> Array[ReactionRule]:
	return []
