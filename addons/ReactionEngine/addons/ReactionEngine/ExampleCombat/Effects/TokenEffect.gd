class_name TokenEffect extends ReactionEffect

## This is a [ReactionEffect] that adds or removes a specific token from the initiator or target.

@export_file("*.tres") var token_path: String # TODO: use _get_property_list to make a better file picker
@export var count: int = 1
@export var to_initiator: bool = false

func apply(ctx: ReactionContext) -> bool:
	var token: Token = load(token_path)
	var target: ReactionEntity = ctx.action.initiator if to_initiator else ctx.action.target
	await ctx.trigger_action(AddTokenAction.new(ctx.action.initiator, target, token, count))
	return true

func get_description() -> String:
	var token: Token = load(token_path)
	if count == 0 or not token:
		return ""
	if count > 0:
		return "ADD %d %s token%s" % [count, token.name, "" if count == 1 else "s"]
	else:
		return "REMOVE %d %s token%s" % [-count, token.name, "" if -count == 1 else "s"]
