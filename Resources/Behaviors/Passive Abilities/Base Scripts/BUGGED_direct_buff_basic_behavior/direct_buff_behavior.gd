extends Behavior
class_name DirectBuffBehavior
## DISCLAIMER We might not use this, keep basic actions for each hero, and infusions and special
## triggering behaviors, keep one action to one unit.
func _execute_behavior_payload(context: CombatContext, is_crit : bool = false):
	# If there are no buffs configured in this spreadsheet row, skip execution
	if data.behaviors_to_apply.is_empty():
		return
	
	for target in context.targets:
		if target == null or target.hero == null:
			continue
			
		# 1. Create your existing CastEffect container
		var effect = create_effect(BuffEffect, target, owner_hero, context.source) as BuffEffect
		
		# 2. Match your spreadsheet configuration variables
		effect.animation = data.animation
		effect.animation_duration = data.animation_duration
		
		# 3. Inject the behaviors payload into the effect's built-in buffs array
		for sub_behavior in data.behaviors_to_apply:
			if sub_behavior:
				print("Adding ", sub_behavior.name, " for ", target.hero.hero_data.name, " at slot ", target.index)
				var behavior = sub_behavior.duplicate()
				if is_crit:
					behavior.stacks = int(behavior.stacks * behavior.crit_multiplier)
				# Duplicate ensures memory isolation and double-pick immunity
				effect.buffs.append(behavior)
		
		# 4. Emit cleanly to your MTG combat stack
		GameEvents.effect_created.emit(effect)
