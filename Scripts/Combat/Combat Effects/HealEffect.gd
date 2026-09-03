extends CombatEffect
class_name HealEffect
var context : CombatContext
# For actions that deal damage as base
func execute(_manager: CombatManager) -> CombatContext:
	context = CombatContext.new(source, [target], _manager)
	if target and target.hero != null:
		var result: Dictionary = target.hero.heal_HP(int(value), source)
		# Below we could add a recorder for heal effects, if we need that, for now we keep it commented
		# context.record_damage(target, result["value"])
		context.record_heal(target, result["value"])
		for b in buffs:
			target.hero.add_behavior(b)
		
	return context

func present(manager: CombatManager) -> void:
	# 1. Source reacts first
	if source and animation != "" and animation != "idle":
		source.play_animation(animation, animation_duration)
		
	# 2. TARGET REACTS SECOND
	if target:
		# We await the exact texture shake tween returned from the slot function!
		var final_heal: int = context.get_heal_dealt_to(target)
		await target.apply_visual_effect(Enums.EffectType.HEAL, is_crit, final_heal).finished
	else:
		# Fallback delay so the coroutine loop doesn't snap if the target is missing
		await manager.get_tree().process_frame
