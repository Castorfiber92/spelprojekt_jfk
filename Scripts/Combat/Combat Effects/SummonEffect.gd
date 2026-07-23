extends CombatEffect
class_name SummonEffect

var hero_to_summon : Hero

func _init(_source: Hero = null, _target: Hero = null, _value: int = 0, _animation: String = "", _animation_duration: float = 0.15, _buffs: Array[Behavior] = []):
	super(_source, _target, 0, _animation, _animation_duration, [])

func execute(_manager: CombatManager) -> void:
	var source_slot: HeroSlot = _manager.hero_to_slot_map.get(source, null)
	_manager.spawn_and_assign_hero(hero_to_summon, source_slot, source_slot.hero.team)

func present(manager: CombatManager) -> void:
	var source_slot: HeroSlot = manager.hero_to_slot_map.get(source, null)
	
	# 1. Source plays animation
	if source_slot and animation != "" and animation != "idle":
		await source_slot.play_animation(animation, animation_duration)
		
	# 2. TARGET REACTS SECOND, if they should from a buff?
	if manager.hero_to_slot_map.has(target):
		var target_slot: HeroSlot = manager.hero_to_slot_map[target]
		await target_slot.apply_heal_effect().finished
	else:
		# Fallback delay so the coroutine loop doesn't snap if the target is missing
		await manager.get_tree().process_frame
