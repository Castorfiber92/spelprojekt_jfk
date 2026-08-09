extends BehaviorData

class_name status_burn_basic_behavior

func _execute_behavior_payload_override(combat_context: CombatContext, executor: Behavior, attack_history: Variant = null):
	var is_tick_crit: bool = executor.roll_crit_local(executor.owner_hero)
	var effect = executor.create_effect(DamageEffect, combat_context.source, executor.owner_hero, combat_context.source) as CombatEffect
	effect.is_crit = is_tick_crit
	effect.value = int(executor.current_stacks * crit_multiplier) if is_tick_crit else executor.current_stacks
	GameEvents.effect_created.emit(effect)
		
	# Tick down and clean up, round down
	executor.current_stacks /= 2
	if executor.current_stacks <= 0:
		executor.owner_hero.remove_behavior(executor)
