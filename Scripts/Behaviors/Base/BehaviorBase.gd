extends Resource
class_name BehaviorBase

@export var name : String
@export var description_long : String
@export var description_short : String
var owner_hero: Hero
@export_category("Type Settings")
enum BehaviorType { PASSIVE, ACTIVE, BUFF }
@export var type: BehaviorType = BehaviorType.PASSIVE
enum BehaviorTag {NEUTRAL, BURN, FROZEN, MARK, STUN}
@export var tag : BehaviorTag = BehaviorTag.NEUTRAL
@export_category("Targeting Settings")
@export var target_team: Enums.Team
@export var target_type: Enums.Target
##0 range for self-targeting or if we are not using a custom range
@export_range(0,5) var range : int
@export_category("Buff Settings")
@export var stacks: int = 0 # 0 if not applicable
@export var blocks_action : bool = false
@export var behaviors_to_apply: Array[Behavior] = []
##Below we will have functions for every event we want to check
##which means on_hit, on_death, on_taking_damage etc etc.
##Then, we create resources for each behaviorData and define what said behavior is doing on every 
##event.

func get_valid_targets(source: HeroSlot, candidates: Array[HeroSlot]) -> Array[HeroSlot]:
	var reachables = get_reachable_targets(source, candidates)
	return _apply_target_type(reachables)
	
func get_reachable_targets(source: HeroSlot, candidates: Array[HeroSlot]) -> Array[HeroSlot]:
	# Only evaluate slots that actually contain a hero
	var active_candidates = candidates.filter(func(slot): return slot.hero != null)
	
	# Attacker Hook
	for b in source.hero.get_behaviors():
		if b.has_method("modify_initial_targets"):
			active_candidates = b.call("modify_initial_targets", active_candidates, source)
		
	var r = range if range > 0 else source.hero.current_range
	var action_range = get_modified_stat(source.hero, "range", r)
	
	var reachables: Array[HeroSlot] = []
	
	if target_team != Enums.Team.FRIEND:
		# Helper to check if a specific frontline index is still alive
		var is_frontline_alive = func(idx: int) -> bool:
			return active_candidates.any(func(slot): return slot.index == idx)
			
		# Separate candidates into structural groups
		var frontline = active_candidates.filter(func(slot): return slot.index <= 1)
		var backline = active_candidates.filter(func(slot): return slot.index > 1)
		
		# Filter for backline units based on hardcoded, explicit safety checks
		var exposed_backline = backline.filter(func(slot):
			match slot.index:
				2: # Top back: exposed if Top front (0) is dead
					return not is_frontline_alive.call(0)
				3: # Mid back: exposed if BOTH Top front (0) and Bot front (1) are dead
					return not is_frontline_alive.call(0) and not is_frontline_alive.call(1)
				4: # Bot back: exposed if Bot front (1) is dead
					return not is_frontline_alive.call(1)
			return false
		)
		
		# --- CHOOSE REACHABLE POOL BY RANGE ---
		if action_range >= 3:
			# Range 3+ / Global: Completely ignores row protection and can target ANY alive enemy.
			reachables = active_candidates
		elif action_range == 2:
			# Range 2 (Snipers): Targets backline first, falls back to frontline if dead.
				reachables = backline if not backline.is_empty() else frontline
		else:
			# Range 1 (Melee): Normal lane-protection rules apply.
			reachables = frontline + exposed_backline
	else:
		# --- FRIENDLY TARGETING FALLBACK ---
		# Friendly targeting (heals/buffs) can reach any ally slot since distance math is gone
		reachables = active_candidates
	
	# Defender Hook (e.g., Taunt)
	for slot in reachables:
		for b in slot.hero.get_behaviors():
			if b.has_method("modify_final_targets"):
				reachables = b.call("modify_final_targets", reachables, slot)
				
	return reachables 
	
func _apply_target_type(candidates: Array[HeroSlot]) -> Array[HeroSlot]:
	if target_type == Enums.Target.SINGLE and not candidates.is_empty():
		return [candidates.pick_random()]
		
	# If it's an AOE/Row action, it returns the whole filtered row
	return candidates
	
func get_distance(source: HeroSlot, target_slot: HeroSlot) -> int:
	if target_team == Enums.Team.FRIEND:
		return abs(source.index - target_slot.index)
	
	# Frontline is distance 1, Backline is distance 2
	return 1 if target_slot.index <= 1 else 2

# This is to check whether there are stats indepent from specific behaviors. Such as flat increases
func get_modified_stat(hero: Hero, stat_name: String, base_value: int) -> int:
	var modified_value = base_value
	var hook_name = "modify_" + stat_name # e.g., "modify_range"
	
	for b in hero.get_behaviors():
		if b.has_method(hook_name):
			modified_value = b.call(hook_name, modified_value)
			
	return modified_value


func on_execute_action(combatContext : CombatContext):
	return []

func on_start_of_battle(combatContext : CombatContext):
	return []

func on_turn_start(combatContext : CombatContext):
	return []

func on_turn_end(combatContext : CombatContext):
	return []

func on_attack(combatContext : CombatContext):
	return []

func on_damage_dealt(combatContext : CombatContext):
	return []

func on_damage_taken(combatContext : CombatContext):
	return []
	
func on_death(combatContext : CombatContext):
	return []

func modify_outgoing_effect(effect : CombatEffect):
	pass
	
func modify_incoming_effect(effect : CombatEffect):
	pass

func modify_initial_targets(active_candidates: Array[HeroSlot], source: HeroSlot) -> Array[HeroSlot]:
	return active_candidates

func modify_final_targets(active_candidates: Array[HeroSlot], source: HeroSlot) -> Array[HeroSlot]:
	return active_candidates

func modify_range(value: int) -> int: return value
func modify_defense(value: int) -> int: return value
func modify_speed(value: int) -> int: return value
