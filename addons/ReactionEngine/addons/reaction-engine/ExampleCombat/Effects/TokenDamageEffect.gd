class_name TokenDamageEffect extends ReactionEffect

## This is a [ReactionEffect] that applies damage based on the number of a specific token the initiator has.

@export var base_damage: int = 0
@export_file("*.tres") var token_path: String
@export var to_initiator: bool = false

func apply(ctx: ReactionContext) -> bool:
	var initiator: ReactionEntity = ctx.action.initiator
	var target: ReactionEntity = ctx.action.target
	var token: Token = load(token_path)
	var token_count = initiator.tokens.get(token, 0)
	var damage = base_damage * token_count
	
	if damage == 0:
		return true
	
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
	var token: Token = load(token_path)
	if base_damage == 0 or not token:
		return ""
	if base_damage < 0:
		return "HEAL %d health for each %s token to %s" % [-base_damage, token.name, "initiator" if to_initiator else "target"]
	return "DAMAGE %d health for each %s token to %s" % [base_damage, token.name, "initiator" if to_initiator else "target"]
