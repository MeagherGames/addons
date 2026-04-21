@abstract class_name TokenModifier extends Resource

## A TokenModifier is a modifier that can be applied to a [Token].
## It can have effects that trigger when the token is added or removed from a [ReactionEntity].

@abstract func _added(ctx: ReactionContext) -> void
@abstract func _removed(ctx: ReactionContext) -> void
