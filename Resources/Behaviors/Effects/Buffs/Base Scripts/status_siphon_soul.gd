extends BehaviorData
class_name Status_siphon_soul

func _execute_behavior_payload_override(combatContext: CombatContext, executor: Behavior, attack_history: Variant = null):
	# If the hp after taking damage is one fourth, e.g. 25% of its max hp, do the effect
	var runtime_owner = executor.owner_hero
	# Change this to take a value instead if you want to be able to modify it/add levels to it
	if runtime_owner.current_HP > 0 and runtime_owner.current_HP <= (runtime_owner.maximum_HP/4):
		# find a target from the resource
		for target in combatContext.targets:
			if target.hero == runtime_owner:
				continue
			## We skip crits as of now for this ability.
			#var rolled_a_crit: bool = executor.roll_crit_local(executor.owner_hero)
			#effect.is_crit = rolled_a_crit
			#if rolled_a_crit:
			var effect = executor.create_effect(ExchangeHPEffect, target, runtime_owner, combatContext.source) as CombatEffect
			GameEvents.effect_created.emit(effect)
