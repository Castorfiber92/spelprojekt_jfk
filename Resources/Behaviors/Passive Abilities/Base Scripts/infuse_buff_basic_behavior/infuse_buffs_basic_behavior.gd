extends BehaviorData
class_name InfuseBuffsModifier

# This script is a dedicated custom modifier for on-hit / rider effects.
# It plugs into the passive modification pipeline, bypassing the trigger gate.

func _execute_outgoing_modification(effect: CombatEffect, is_behavior_crit: bool):
	# Read 'behaviors_to_apply' directly from self (this resource)
	if trigger_on_innate_crit and not effect.is_crit:
		return
	if proc_chance < 1.0 and randf() > proc_chance:
		return

	for buff_data in behaviors_to_apply:
		var behavior_runtime = Behavior.create(buff_data)
		# Check whether the crit is already a crit OR if it is set to check the innate crit of the hero and
		# the original action has already critted OR this buff is set to force critical strike
		var is_total_crit = is_behavior_crit or (trigger_on_innate_crit and effect.is_crit) or force_critical_strike
		if is_total_crit:
			# If this behavior forces a critical strike, update the global container flag
			if force_critical_strike:
				effect.is_crit = true
			# Apply the critted amount of stacks
			behavior_runtime.current_stacks = int(buff_data.base_stacks * crit_multiplier)
		else:
			behavior_runtime.current_stacks = buff_data.base_stacks
			
		# Pushes the clean runtime Behavior instance directly into the array safely
		effect.buffs.append(behavior_runtime)
