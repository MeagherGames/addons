class_name AddTokenAction extends ReactionAction

## This is a [ReactionAction] that adds a specific token to the target.
## It can also be used to remove tokens by passing a negative count. 
## The actual count added or removed is returned.

var token: Token = null
var count: int = 1

@warning_ignore("shadowed_variable", "shadowed_variable_base_class")
func _init(initiator: ReactionEntity, target: ReactionEntity, token: Token = null, count: int = 1) -> void:
	super._init(initiator, target)
	self.token = token
	self.count = count

func _execute(ctx: ReactionContext) -> int:
	var current_count = target.tokens.get(token, 0)
	var new_count = max(0, current_count + count)
	if token.max_count > 0:
		new_count = min(new_count, token.max_count)
	
	if new_count > 0:
		if current_count == 0:
			token.on_added(ctx)
		target.tokens[token] = new_count
	elif target.tokens.has(token):
		target.tokens.erase(token)
		token.on_removed(ctx)
	
	target.tokens_changed.emit()
	return new_count - current_count
