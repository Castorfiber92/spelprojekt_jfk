extends BehaviorData
class_name BasicActionBehavior

enum ActionType { ATTACK, CAST }
@export var action_profile: ActionType = ActionType.ATTACK
	
# We add '_executor: Behavior' as a parameter to safely proxy runtime operations
func _execute_behavior_payload_override(combatContext: CombatContext, executor: Behavior, attack_history: Variant = null):
	var source_slot = combatContext.source
	var rolled_a_crit: bool = randf() < source_slot.hero.current_crit_chance
	var runtime_owner = executor.owner_hero
	for target in combatContext.targets:
		match action_profile:
			ActionType.ATTACK:
				# Use the runtime executor instance to access factory methods and unique ownership details
				var effect = executor.create_effect(DamageEffect, target, runtime_owner, source_slot) as CombatEffect
				effect.is_crit = rolled_a_crit
				var final_damage = source_slot.hero.current_damage
				if rolled_a_crit:
					# We read crit_multiplier cleanly from the local resource instance properties
					final_damage = int(final_damage * crit_multiplier)
				effect.value = final_damage
				GameEvents.effect_created.emit(effect)
				
			ActionType.CAST:
				var effect = executor.create_effect(BuffEffect, target, runtime_owner, source_slot) as CombatEffect
				effect.is_crit = rolled_a_crit
				
				for behavior_data in behaviors_to_apply:
					var new_runtime_buff = Behavior.create(behavior_data)
					if rolled_a_crit:
						new_runtime_buff.current_stacks = int(behavior_data.base_stacks * crit_multiplier)
				GameEvents.effect_created.emit(effect)
