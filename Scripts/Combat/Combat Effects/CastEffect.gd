extends CombatEffect
class_name CastEffect

# For actions that apply buffs ONLY
func execute(_manager: CombatManager) -> void:
	var source_slot: HeroSlot = _manager.hero_to_slot_map.get(source, null)
	for b in buffs:
		target.add_behavior(b.duplicate())


func present(manager: CombatManager) -> void:
	var source_slot: HeroSlot = manager.hero_to_slot_map.get(source, null)
	
	# 1. Source plays animation
	if source_slot and animation != "" and animation != "idle":
		await source_slot.play_animation(animation, animation_duration)
		
	# 2. TARGET REACTS SECOND, if they should from a buff?
	#if manager.hero_to_slot_map.has(target):
		#var target_slot: HeroSlot = manager.hero_to_slot_map[target]
		#await target_slot.apply_damage_effect(is_crit).finished
	#else:
		# Fallback delay so the coroutine loop doesn't snap if the target is missing
	await manager.get_tree().process_frame
