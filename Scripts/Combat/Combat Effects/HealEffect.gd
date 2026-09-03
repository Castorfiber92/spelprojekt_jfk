extends CombatEffect
class_name HealEffect

func execute(_manager: CombatManager) -> void:
	if target and target.hero != null:
		# The hero node mutates its own data natively and handles its own signal emissions!
		target.hero.heal_HP(int(value), source)
		
		for b in buffs:
			target.hero.add_behavior(b)

func present(manager: CombatManager) -> void:
	if source and animation != "" and animation != "idle":
		source.play_animation(animation, animation_duration)
		
	if target and target.hero != null:
		# Simply read the direct raw 'value' parameter for the floating text label!
		await target.apply_visual_effect(Enums.EffectType.HEAL, is_crit, int(value)).finished
	else:
		await manager.get_tree().process_frame
