extends BehaviorData

class_name status_burn_basic_behavior


func on_turn_start(combatContext: CombatContext, executor: Behavior, attack_history: Variant = null) -> void:
	var is_tick_crit: bool = executor.roll_crit_local(executor.owner_hero)
	var effect = executor.create_effect(DamageEffect, combatContext.source, combatContext.source) as CombatEffect
	effect.is_crit = is_tick_crit
	effect.value = int(executor.current_stacks * crit_multiplier) if is_tick_crit else executor.current_stacks
	GameEvents.effect_created.emit(effect)
		
	executor.current_stacks /= 2
	if executor.current_stacks <= 0:
		executor.owner_hero.remove_behavior(executor)
