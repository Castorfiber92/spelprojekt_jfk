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
	var r = range if range > 0 else source.hero.current_range
	var action_range = get_modified_stat(source.hero, "range", r)
	
	# Only evaluate slots that actually contain a hero
	var active_candidates = candidates.filter(func(slot): return slot.hero != null)
	
	# 2. ATTACKER HOOK: Let attacker behaviors modify the candidate pool (e.g., bypass rules)
	for b in source.hero.get_behaviors():
		if b.has_method("modify_initial_targets"):
			active_candidates = b.call("modify_initial_targets", active_candidates, source)
			
	# Filter strictly by physical distance rule
	var reachables = active_candidates.filter(func(slot): 
		return get_distance(source, slot) <= action_range
	)
	# 4. DEFENDER HOOK: Let defender behaviors restrict the reachable pool (e.g., Taunt)
	for slot in reachables:
		for b in slot.hero.get_behaviors():
			if b.has_method("modify_final_targets"):
				# A Taunt behavior checks if the tank is in 'reachables', and if so, returns ONLY the tank
				reachables = b.call("modify_final_targets", reachables, slot)
				
	return reachables 
	
func _apply_target_type(candidates: Array[HeroSlot]) -> Array[HeroSlot]:
	# Currently only checking for single cases
	if target_type == Enums.Target.SINGLE and not candidates.is_empty():
		# If so, pick at random (CURRENTLY)
		return [candidates.pick_random()]
	# If it is not a single target action, it just returns the original candidates
	return candidates
	
func get_distance(source: HeroSlot, target_slot: HeroSlot) -> int:
	var source_row = 0 if source.index <= 2 else 1
	var target_row = 0 if target_slot.index <= 2 else 1
	
	if target_team == Enums.Team.FRIEND:
		# Simple grid/lane distance if needed, or row difference
		return abs(source.index - target_slot.index)
	else:
		# Cross-team distance: Row 0 to Row 0 is 1 step. 
		# Row 0 to Row 1 is 2 steps. Row 1 to Row 1 is 3 steps.
		return source_row + target_row + 1

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
