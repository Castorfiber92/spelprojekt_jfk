extends BehaviorData
class_name Status_trollhide

# Value is how much damage reduction we do
# Max value is how much total healing/round we allow
# Min value is how low damage we always take
# stacks is the amount to be healed
func modify_incoming_effect(effect: CombatEffect, executor: Behavior):
	if effect is DamageEffect:
		effect.value = maxi(min_value, effect.value - value)
		executor.current_stacks = min(executor.current_stacks + 1, max_value)

# Heals as much as the current stacks are, which are increased every time the hero is struck by a damage effect.
func on_turn_start(combatContext: CombatContext, executor: Behavior, attack_history: Variant = null):
	if executor.current_stacks <= 0:
		return
	var effect = executor.create_effect(HealEffect, combatContext.source, combatContext.source) as CombatEffect
	effect.origin = CombatEffect.EffectOrigin.STATUS_TICK
	effect.value = executor.current_stacks
	GameEvents.effect_created.emit(effect)
