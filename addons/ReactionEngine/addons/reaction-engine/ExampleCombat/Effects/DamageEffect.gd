class_name DamageEffect extends ReactionEffect

## This is a [ReactionEffect] that applies flat damage to the target or initiator.

@export var damage: int = 0
@export var to_initiator: bool = false

func apply(ctx: ReactionContext) -> bool:
	var initiator: ReactionEntity = ctx.action.initiator
	var target: ReactionEntity = ctx.action.target
	
	if to_initiator:
		var action = AttackAction.new(target, initiator, damage)
		await ctx.trigger_action(action)
		return true
	
	if ctx.action is AttackAction:
		ctx.action.damage += damage
	else:
		var action = AttackAction.new(initiator, target, damage)
		await ctx.trigger_action(action)
	return true

func get_description() -> String:
	if damage == 0:
		return ""
	if damage < 0:
		return "HEAL %d health to %s" % [-damage, "initiator" if to_initiator else "target"]
	return "DAMAGE %d health to %s" % [damage, "initiator" if to_initiator else "target"]
