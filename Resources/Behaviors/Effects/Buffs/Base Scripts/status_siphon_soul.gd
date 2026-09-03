extends BehaviorData
class_name Status_siphon_soul

func on_damage_taken(combatContext: CombatContext, executor: Behavior, attack_history: Variant = null):
	var runtime_owner = executor.owner_hero
	var active_max_hp = runtime_owner.get_stat(Enums.StatType.MAX_HP)
	var execution_threshold = active_max_hp / 4
	
	if runtime_owner.current_HP > 0 and runtime_owner.current_HP <= execution_threshold:
		for target in combatContext.targets:
			if target.hero == runtime_owner:
				continue
				
			# STRUCTURAL FIX: Updated parameters to match our return-free, streamlined blueprint
			var effect = executor.create_effect(ExchangeHPEffect, target, combatContext.source) as CombatEffect
			GameEvents.effect_created.emit(effect)
