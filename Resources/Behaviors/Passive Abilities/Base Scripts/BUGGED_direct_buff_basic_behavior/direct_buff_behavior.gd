extends BehaviorData
class_name DirectBuffBehavior
## DISCLAIMER We might not use this, keep basic actions for each hero, and infusions and special
## triggering behaviors, keep one action to one unit.
func _execute_behavior_payload_override(combatContext: CombatContext, executor: Behavior):
	var source_slot = combatContext.source
	var rolled_a_crit: bool = randf() < source_slot.hero.get_stat(Enums.StatType.CRIT)
	var runtime_owner = executor.owner_hero
	for target in combatContext.targets:
		var effect = executor.create_effect(BuffEffect, target, runtime_owner, source_slot) as CombatEffect
		effect.is_crit = rolled_a_crit
				
		for behavior_data in behaviors_to_apply:
			var new_runtime_buff = Behavior.create(behavior_data)
			if rolled_a_crit:
				new_runtime_buff.current_stacks = int(behavior_data.base_stacks * crit_multiplier)
		GameEvents.effect_created.emit(effect)
