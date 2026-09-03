extends CombatEffect
class_name BuffEffect

# For actions that apply buffs 
func execute(_manager: CombatManager) -> Variant:
	if target == null or target.hero == null:
		print("BuffEffect fizzled: Target hero is no longer on the battlefield.")
		return
	for b : Behavior in buffs:
		print("adding ", b.current_stacks, " stacks")
		target.hero.add_behavior(b)
	return


func present(manager: CombatManager) -> void:
	# 1. Source plays animation
	if source and animation != "" and animation != "idle":
		source.play_animation(animation, animation_duration)
		
	# 2. TARGET REACTS SECOND, if they should from a buff?
	if target != null:
		if effect_owner.team == target.hero.team:
			await target.apply_visual_effect(Enums.EffectType.HEAL, is_crit, -1, false).finished
		else:
			await target.apply_visual_effect(Enums.EffectType.DAMAGE,is_crit, -1, false).finished
	else:
		# Fallback delay so the coroutine loop doesn't snap if the target is missing
		await manager.get_tree().process_frame
