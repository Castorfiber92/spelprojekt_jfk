extends Resource
class_name BehaviorBase

@export var name : String
var owner_hero: Hero
@export_category("Targeting Settings")
@export var target_team: Enums.Team
@export var target_type: Enums.Target
##0 range for self-targeting or if we are not using a custom range
@export_range(0,5) var range : int
##Below we will have functions for every event we want to check
##which means on_hit, on_death, on_taking_damage etc etc.
##Then, we create resources for each behaviorData and define what said behavior is doing on every 
##event.

func get_valid_targets(source: HeroSlot, candidates: Array[HeroSlot]) -> Array[HeroSlot]:
	var reachables = get_reachable_targets(source, candidates)
	return _apply_target_type(reachables)
	
func get_reachable_targets(source: HeroSlot, candidates: Array[HeroSlot]) -> Array[HeroSlot]:

	var reachables: Array[HeroSlot] = []
	# Determine the range to use, if the range of the action is set to 0 we use the range of the hero
	var r = range if range > 0 else source.hero.current_range
	# Then we check all behaviors if there are any that modifies stats, in this case range.
	var action_range = get_modified_stat(source.hero, "range", r)
	
	# This is a filter check and a lambda that checks if there is an actual hero in each slot,
	# if it is, it stays, if not, we remove it.
	# When the filter is done we return it.
	var active_candidates = candidates.filter(func(slot): return slot.hero != null)
	
	if target_team == Enums.Team.FRIEND:
		for slot in active_candidates:
			var dist = abs(source.index - slot.index)
			if dist <= action_range:
				reachables.append(slot)
		return reachables
	# To make sure the array has the correct index for the enemies so the range check works properly
	active_candidates.sort_custom(func(a, b): return a.index < b.index)
	
	for i in range(active_candidates.size()):
		if (i + 1) <= action_range:
			reachables.append(active_candidates[i])
			
	return reachables

func _apply_target_type(candidates: Array[HeroSlot]) -> Array[HeroSlot]:
	# Currently only checking for single cases
	if target_type == Enums.Target.SINGLE and not candidates.is_empty():
		# If so, pick at random (CURRENTLY)
		return [candidates.pick_random()]
	# If it is not a single target action, it just returns the original candidates
	return candidates
	
func get_distance(source: HeroSlot, target_slot: HeroSlot) -> int:
	# If they are on the same team, it's just the difference (e.g., 0 and 2 is dist 2)
	if target_team == Enums.Team.FRIEND:
		return abs(source.index - target_slot.index)
	# If opposing teams, add indices + 1 (e.g., Front(0) to Front(0) is dist 1)
	return source.index + target_slot.index + 1

# This is to check whether there are stats indepent from specific behaviors. Such as flat increases
func get_modified_stat(hero: Hero, stat_name: String, base_value: int) -> int:
	var modified_value = base_value
	var hook_name = "modify_" + stat_name # e.g., "modify_range"
	
	for b in hero.get_behaviors():
		if b.has_method(hook_name):
			modified_value = b.call(hook_name, modified_value)
			
	return modified_value


func on_execute_action(data):
	return []

func on_start_of_battle(data):
	return []

func on_attack(data):
	return []

func on_damage_dealt(data):
	return []

func on_damage_taken(data):
	return []
	
func on_death(data):
	return []

func modify_outgoing_effect(effect : CombatEffect):
	pass
	
func modify_incoming_effect(effect : CombatEffect):
	pass

func modify_range(value: int) -> int: return value
func modify_defense(value: int) -> int: return value
func modify_speed(value: int) -> int: return value
