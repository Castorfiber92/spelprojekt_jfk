extends BehaviorData
class_name Status_Trollhide

func modify_incoming_effect(effect : CombatEffect, executor: Behavior):
	# Reduce stacks accordingly to damage, only if it is a damaging effect
	if effect is DamageEffect:
		# Reduce the incoming damage value by 2, always making sure to take 1 damage
		effect.value = maxi(min_value, effect.value - value)
		# Add 1 stack for the healing amount, making sure it does not go above 10.
		executor.current_stacks = min(executor.current_stacks + 1, max_value)
	
func _execute_behavior_payload_override(combatContext: CombatContext, executor: Behavior):
	var rolled_a_crit: bool = executor.roll_crit_local(executor.owner_hero)
	var runtime_owner = executor.owner_hero
	var effect = executor.create_effect(HealEffect, combatContext.source, runtime_owner, combatContext.source) as CombatEffect
	effect.is_crit = rolled_a_crit
	var final_heal = value
	if rolled_a_crit:
		# We read crit_multiplier cleanly from the local resource instance properties
		effect.value = int(final_heal * crit_multiplier) if rolled_a_crit else effect.value
	effect.value = final_heal
	GameEvents.effect_created.emit(effect)
	
