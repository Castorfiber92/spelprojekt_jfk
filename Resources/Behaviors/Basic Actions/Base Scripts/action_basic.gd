extends BehaviorData
class_name BasicActionBehavior

enum ActionType { ATTACK, CAST }
@export var action_profile: ActionType = ActionType.ATTACK
	
func on_execute_action(combatContext: CombatContext, executor: Behavior, attack_history: Variant = null) -> void:
	var source_slot = combatContext.source
	if source_slot == null or source_slot.hero == null: return
	
	var rolled_a_crit: bool = executor.roll_crit_local(source_slot.hero)
	var runtime_owner = executor.owner_hero
	
	for target in combatContext.targets:
		match action_profile:
			ActionType.ATTACK:
				var effect = executor.create_effect(DamageEffect, target, source_slot) as DamageEffect
				effect.is_crit = rolled_a_crit
				
				var final_damage = source_slot.hero.get_stat(Enums.StatType.DAMAGE)
				if rolled_a_crit:
					final_damage = int(final_damage * crit_multiplier)
					
				effect.value = final_damage
				GameEvents.effect_created.emit(effect)
				
			ActionType.CAST:
				var effect = executor.create_effect(BuffEffect, target, source_slot) as BuffEffect
				effect.is_crit = rolled_a_crit
				
				if rolled_a_crit and crit_multiplier > 1.0:
					for b in effect.buffs:
						b.current_stacks = int(b.current_stacks * crit_multiplier)
						
				GameEvents.effect_created.emit(effect)
