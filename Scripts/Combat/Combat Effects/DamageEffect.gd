extends CombatEffect
class_name DamageEffect
var context : CombatContext
# For actions that deal damage as base
func execute(_manager: CombatManager) -> CombatContext:
	context = CombatContext.new(source, [target], _manager)
	if target and target.hero != null:
		var result: Dictionary = target.hero.take_damage(int(value), source)
		context.record_damage(target, result["damage"], result["was_lethal"])
		for b in buffs:
			target.hero.add_behavior(b)
		
	return context

func present(manager: CombatManager) -> void:
	# 1. ATTACKER STRIKES FIRST
	if source and animation != "" and animation != "idle":
		source.play_animation(animation, animation_duration)
		
	# 2. TARGET REACTS SECOND
	if target:
		# We await the exact texture shake tween returned from the slot function!
		var final_damage: int = context.get_damage_dealt_to(target)
		await target.apply_visual_effect(Enums.EffectType.DAMAGE, is_crit, final_damage).finished
	else:
		# Fallback delay so the coroutine loop doesn't snap if the target is missing
		await manager.get_tree().process_frame
