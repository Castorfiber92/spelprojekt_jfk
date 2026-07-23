extends CombatEffect
class_name HealEffect

# For actions that heal as base
func execute(_manager: CombatManager) -> void:
	var source_slot: HeroSlot = _manager.hero_to_slot_map.get(source, null)
	if target:
		await target.heal_HP(value, source)
	for b in buffs:
		target.add_behavior(b)
		
func present(manager: CombatManager) -> void:
	var source_slot: HeroSlot = manager.hero_to_slot_map.get(source, null)
	
	if source_slot and animation != "" and animation != "idle":
		await source_slot.play_animation(animation, animation_duration)
		
	#  Crash Guard for healing targets
	if manager.hero_to_slot_map.has(target):
		var target_slot: HeroSlot = manager.hero_to_slot_map[target]
		await target_slot.apply_heal_effect().finished
	else:
		await manager.get_tree().process_frame
