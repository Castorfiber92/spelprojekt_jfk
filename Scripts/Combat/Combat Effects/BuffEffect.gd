extends CombatEffect
class_name BuffEffect

func execute(_manager: CombatManager) -> void:
	if target == null or target.hero == null:
		print("BuffEffect fizzled: Target hero is no longer on the battlefield.")
		return
		
	for b in buffs:
		target.hero.add_behavior(b)

func present(manager: CombatManager) -> void:
	if source and animation != "" and animation != "idle":
		source.play_animation(animation, animation_duration)
		
	if target != null and target.hero != null:
		# Use your existing team alignments to color the UI highlights cleanly
		if effect_owner.team == target.hero.team:
			await target.apply_visual_effect(Enums.EffectType.HEAL, is_crit, -1, false).finished
		else:
			await target.apply_visual_effect(Enums.EffectType.DAMAGE, is_crit, -1, false).finished
	else:
		await manager.get_tree().process_frame
