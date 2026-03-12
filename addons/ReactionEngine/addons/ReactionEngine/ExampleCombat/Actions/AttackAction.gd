class_name AttackAction extends ReactionAction

## This is a [ReactionAction] that applies damage from the initiator to the target.
## It triggers the appropriate rules for attacking, being attacked, dealing damage, and taking damage.

const ON_ATTACK = preload("../Triggers/Attack.tres")
const ON_ATTACKED = preload("../Triggers/Attacked.tres")
const ON_DAMAGE_TAKEN = preload("../Triggers/DamageTaken.tres")
const ON_DAMAGE_DEALT = preload("../Triggers/DamageDealt.tres")
const ON_DEATH = preload("../Triggers/Death.tres")
const ON_REVIVE = preload("../Triggers/Revive.tres")

var damage: int = 0

@warning_ignore("shadowed_variable", "shadowed_variable_base_class")
func _init(initiator: ReactionEntity, target: ReactionEntity, damage: int = 0, types: Array[String] = []) -> void:
	super._init(initiator, target)
	self.damage = damage
	self.types = types

func _execute(ctx: ReactionContext) -> void:
	await ctx.trigger_rules(initiator, ON_ATTACK)
	await ctx.trigger_rules(target, ON_ATTACKED)

	var current_health = target.health
	await ctx.trigger_rules(target, ON_DAMAGE_TAKEN)
	target.health -= damage
	if damage != 0:
		await ctx.trigger_rules(initiator, ON_DAMAGE_DEALT)
		if current_health > 0 and target.health <= 0:
			target.die()
			await ctx.trigger_rules(target, ON_DEATH)
		elif current_health <= 0 and target.health > 0:
			target.revive()
			await ctx.trigger_rules(target, ON_REVIVE)
