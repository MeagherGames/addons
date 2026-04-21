class_name ConsumeTokenEffect extends ReactionEffect

## This is a [ReactionEffect] that consumes a specific token from the target. If the target doesn't have enough tokens, the effect chain is stopped.

@export_file("*.tres") var token_path: String
@export_range(1, 1, 1, "or_greater") var count: int = 1

func apply(ctx: ReactionContext) -> bool:
	var token: Token = load(token_path)
	if ctx.action.target.tokens.get(token, 0) < count:
		return false # Not enough tokens to consume
	var removed_count: int = await ctx.trigger_action(AddTokenAction.new(
		ctx.action.initiator,
		ctx.action.target,
		token,
		- count
	))
	return removed_count >= count

func get_description() -> String:
	var token: Token = load(token_path)
	if count == 0 or not token:
		return ""

	## TODO add hover info for token CONSUME details and STOP effect chain
	return "\n".join([
		"CONSUME %d %s token%s" % [count, token.name, "" if count == 1 else "s"],
		"If no token to consume, STOP effect chain"
	])
