@abstract class_name ReactionEffect extends Resource

## Applies the effect to the given action.
## Return false to stop the effect chain.
@abstract func apply(ctx: ReactionContext) -> bool

@abstract func get_description() -> String