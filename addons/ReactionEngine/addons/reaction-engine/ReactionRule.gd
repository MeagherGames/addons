class_name ReactionRule extends Resource

@export var trigger: ReactionTrigger = null
@export var effects: Array[ReactionEffect] = []
@export_range(0, 1, 1, "or_greater") var trigger_limit: int = 0 ## The maximum number of times this rule can be triggered on an entity (0 = unlimited).

func apply(ctx: ReactionContext) -> bool:
	for effect in effects:
		@warning_ignore("redundant_await")
		if not await effect.apply(ctx):
			return false
	return true

func get_description() -> String:
	var descriptions: Array[String] = []
	for effect in effects:
		var effect_desc = effect.get_description()
		if effect_desc != "":
			descriptions.append(effect_desc)
	
	if descriptions.size() == 0:
		return ""
	
	return trigger.on_text + ": " + ", ".join(descriptions)
