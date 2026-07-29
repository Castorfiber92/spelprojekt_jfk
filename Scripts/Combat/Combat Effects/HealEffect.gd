extends CombatEffect
class_name HealEffect

# For actions that heal as base
func execute(_manager: CombatManager) -> Variant:
	if target:
		await target.heal_HP(value, source)
	for b in buffs:
		target.hero.add_behavior(b)
	return
		
func present(manager: CombatManager) -> void:
	
	if source and animation != "" and animation != "idle":
		await source.play_animation(animation, animation_duration)
		
	#  Crash Guard for healing targets
	if target:
		var target: HeroSlot = manager.hero_to_slot_map[target]
		await target.apply_heal_effect().finished
	else:
		await manager.get_tree().process_frame
