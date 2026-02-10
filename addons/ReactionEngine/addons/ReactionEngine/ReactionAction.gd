@abstract class_name ReactionAction extends RefCounted

var initiator: ReactionEntity
var target: ReactionEntity

@warning_ignore("shadowed_variable")
func _init(initiator: ReactionEntity, target: ReactionEntity) -> void:
	self.initiator = initiator
	self.target = target

@abstract func _execute(ctx: ReactionContext) # Can return anything
