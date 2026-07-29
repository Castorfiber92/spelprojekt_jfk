extends BehaviorData
class_name InfuseBuffsModifier

# This script is a dedicated custom modifier for on-hit / rider effects.
# It plugs into the passive modification pipeline, bypassing the trigger gate.

func _execute_outgoing_modification(effect: CombatEffect, is_behavior_crit: bool):
	# Read 'behaviors_to_apply' directly from self (this resource)
	for buff_data in behaviors_to_apply:
		var behavior_runtime = Behavior.create(buff_data)
		
		if is_behavior_crit:
			# FIX 2: Multiply using the base value from the static config template asset
			behavior_runtime.current_stacks = int(buff_data.base_stacks * crit_multiplier)
			
		# Pushes the clean runtime Behavior instance directly into the array safely
		effect.buffs.append(behavior_runtime)
