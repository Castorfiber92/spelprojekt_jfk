extends BehaviorData
class_name Status_trollhide

# Inside Status_trollhide.gd
func modify_incoming_effect(effect: CombatEffect, executor: Behavior):
	if effect is DamageEffect:
		effect.value = maxi(min_value, effect.value - value)
		executor.current_stacks = min(executor.current_stacks + 1, max_value)

# Instead of extracting contexts, it just executes a direct action on its owner!
func on_turn_start(combatContext: CombatContext, executor: Behavior, attack_history: Variant = null):
	var effect = executor.create_effect(HealEffect, combatContext.source, combatContext.source) as CombatEffect
	effect.value = executor.current_stacks
	GameEvents.effect_created.emit(effect)
