extends CombatEffect
class_name DamageEffect

# For actions that deal damage as base
func execute(_manager: CombatManager) -> CombatContext:
	var context = CombatContext.new(source, [target], _manager)
	if target and target.hero != null:
		var result: Dictionary = target.hero.take_damage(int(value), source)
		context.record_damage(target, result["damage"], result["was_lethal"])
		for b in buffs:
			target.hero.add_behavior(b)
		
	return context

func present(manager: CombatManager) -> void:
	# 1. ATTACKER STRIKES FIRST
	if source and animation != "" and animation != "idle":
		await source.play_animation(animation, animation_duration)
		
	# 2. TARGET REACTS SECOND
	if target:
		# We await the exact texture shake tween returned from the slot function!
		await target.apply_damage_effect(is_crit).finished
	else:
		# Fallback delay so the coroutine loop doesn't snap if the target is missing
		await manager.get_tree().process_frame
