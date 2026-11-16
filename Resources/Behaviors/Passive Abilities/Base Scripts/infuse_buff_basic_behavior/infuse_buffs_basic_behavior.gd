extends BehaviorData
class_name InfuseBuffsModifier

# Right now this triggers on ALL and ONLY basic actions (Attack/Cast), not status ticks or reflect effects.
# Look into the Combat Effect to see how that is set up.

# This script is a dedicated custom modifier for on-hit / rider effects.
# It plugs into the passive modification pipeline, bypassing the trigger gate.

func modify_outgoing_effect(effect: CombatEffect, executor: Behavior):
	if effect.origin == CombatEffect.EffectOrigin.STATUS_TICK:
		return
	for buff_data in behaviors_to_apply:
		var behavior_runtime = Behavior.create(buff_data)
		
		# If either the local action critted OR it was forced, multiply the stacks
		if effect.is_crit:
			behavior_runtime.current_stacks = int(behavior_runtime.current_stacks * crit_multiplier)
			
		effect.buffs.append(behavior_runtime)
