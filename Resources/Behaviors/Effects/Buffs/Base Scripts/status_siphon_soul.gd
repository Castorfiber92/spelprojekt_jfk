extends BehaviorData
class_name Status_siphon_soul

func on_damage_taken(combatContext: CombatContext, executor: Behavior, attack_history: Variant = null):
	var runtime_owner = executor.owner_hero
	var active_max_hp = runtime_owner.get_base_stat(Enums.StatType.HP)
	var execution_threshold = active_max_hp / 4
	
	if runtime_owner.get_current_stat(Enums.StatType.HP) > 0 and runtime_owner.get_current_stat(Enums.StatType.HP) <= execution_threshold:
		## TARGET BECOMES THE SOURCE HERE, PROBABLY NOT LOADING THE NEW TARGETTING SYSTEM
		for target in combatContext.targets:
			#
			var effect = executor.create_effect(ExchangeHPEffect, target, combatContext.source)
			GameEvents.effect_created.emit(effect)
