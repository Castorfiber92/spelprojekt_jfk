extends CombatEffect
class_name SummonEffect

var hero_to_summon : HeroData
var cached_team : Enums.Team # Saved by the behavior trigger payload at birth

func execute(_manager: CombatManager) -> Variant:
	if hero_to_summon == null or source == null:
		print("SummonEffect fizzled: Data or target slot metadata corrupted.")
		return
		
	# STEP 1: Verify that the slot left behind by the dead unit is currently vacant.
	# (Your stack's Step 2 guarantees this is empty!)
	if source.hero != null:
		print("SummonEffect fizzled: The slot ", source.name, " is already occupied by someone else!")
		return
		
	# STEP 2: Spawn the minion and assign it straight to this empty death slot!
	_manager.spawn_and_assign_hero(hero_to_summon, source, cached_team)
	print("Deathrattle Success: Reoccupied slot ", source.name, " with summon: ", hero_to_summon.name)
	return

func present(manager: CombatManager) -> void:
	# 1. Source caster plays their channel/summon animation first
	#if source and animation != "" and animation != "idle":
		#await source.play_animation(animation, animation_duration)
		
	# 2. Summon visual animation sequence
	# We need to find where the manager spawned the new hero so we can animate its slot!
	# Assume your manager has a way to look up the slot containing the newly spawned minion.
	#var spawned_slot = manager.get_slot_by_hero_data(hero_to_summon)
	
	#if spawned_slot:
		# Play your custom spawn effect animation on the new slot (e.g., "spawn", "fade_in", "bounce")
		# We await it so the combat timeline pauses naturally while the minion arrives!
		#await spawned_slot.play_animation("spawn", 0.25)
	#else:
		# Fallback process delay so the coroutine sequence never snaps if the slot is elusive
	await manager.get_tree().process_frame
