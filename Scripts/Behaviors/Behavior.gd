extends RefCounted
class_name Behavior

var data: BehaviorData # Holds our configuration parameters safely
var owner_hero: Hero   # Unique runtime owner, completely safe from overwrites!
var current_stacks: int

static func create(_data : BehaviorData) -> Behavior:
	var instance = Behavior.new()
	var duplicated_data = _data.duplicate(true)
	var sterile_array: Array[BehaviorData] = []
	for nested_res in duplicated_data.behaviors_to_apply:
		if nested_res != null:
			# Explicitly clone the sub-resources so they can never share memory blocks
			sterile_array.append(nested_res.duplicate(true))
	duplicated_data.behaviors_to_apply = sterile_array
	instance.data = duplicated_data
	instance.current_stacks = _data.base_stacks
	return instance

# --- CLEANED DIRECT PASS-THROUGH HOOKS ---
func route_to_matching_hook(event_type: Enums.TriggerEvent, context: CombatContext, history: Variant) -> void:
	match event_type:
		# FIXED: Calls the local pass-through hook on 'self', which cleanly passes 
		# the context, the runtime instance, and the history down to your scripts!
		Enums.TriggerEvent.ON_EXECUTE_ACTION: on_execute_action(context, history)
		Enums.TriggerEvent.ON_START_OF_BATTLE: on_start_of_battle(context, history)
		Enums.TriggerEvent.ON_TURN_START: on_turn_start(context, history)
		Enums.TriggerEvent.ON_TURN_END: on_turn_end(context, history)
		Enums.TriggerEvent.ON_ATTACK: on_attack(context, history)
		Enums.TriggerEvent.ON_DAMAGE_DEALT: on_damage_dealt(context, history)
		Enums.TriggerEvent.ON_DAMAGE_TAKEN: on_damage_taken(context, history)
		Enums.TriggerEvent.ON_DEATH: on_death(context, history)
		Enums.TriggerEvent.ON_ROUND_END: on_round_end(context, history)

# ==============================================================================
# Direct Pass-Through Event Hooks
# ==============================================================================
func on_execute_action(context: CombatContext, history: Variant = null) -> void: 
	if data.has_method("on_execute_action"): data.on_execute_action(context, self, history)

func on_start_of_battle(context: CombatContext, history: Variant = null) -> void: 
	if data.has_method("on_start_of_battle"): data.on_start_of_battle(context, self, history)

func on_turn_start(context: CombatContext, history: Variant = null) -> void:     
	if data.has_method("on_turn_start"): data.on_turn_start(context, self, history)

func on_turn_end(context: CombatContext, history: Variant = null) -> void:       
	if data.has_method("on_turn_end"): data.on_turn_end(context, self, history)

func on_attack(context: CombatContext, history: Variant = null) -> void:         
	if data.has_method("on_attack"): data.on_attack(context, self, history)

func on_damage_dealt(context: CombatContext, history: Variant = null) -> void:   
	if data.has_method("on_damage_dealt"): data.on_damage_dealt(context, self, history)

func on_damage_taken(context: CombatContext, history: Variant = null) -> void:   
	if data.has_method("on_damage_taken"): data.on_damage_taken(context, self, history)

func on_death(context: CombatContext, history: Variant = null) -> void:          
	if data.has_method("on_death"): data.on_death(context, self, history)

func on_round_end(context: CombatContext, history: Variant = null) -> void:      
	if data.has_method("on_round_end"): data.on_round_end(context, self, history)


func modify_outgoing_effect(effect : CombatEffect):
# Path A: Gated flow. If the resource implements 'modify_outgoing_effect', 
	# it wants to run through the trigger gates first.
	if data.has_method("modify_outgoing_effect"):
		if data.trigger_on_innate_crit and not effect.is_crit:
			return
		if data.proc_chance < 1.0 and randf() > data.proc_chance:
			return
		var is_local_crit: bool = data.force_critical_strike or (data.trigger_on_innate_crit and effect.is_crit)
		
		# Pass the call to the resource, providing 'self' as the runtime executor state
		data.modify_outgoing_effect(effect, is_local_crit, self)
		
	# Path B: Direct execution override (Like InfuseBuffsModifier)
	elif data.has_method("_execute_outgoing_modification"):
		data._execute_outgoing_modification(effect, effect.is_crit)

func _execute_outgoing_modification(effect: CombatEffect, is_behavior_crit : bool):
	if data.has_method("_execute_outgoing_modification"):
		data._execute_outgoing_modification(effect, is_behavior_crit)
	
func modify_incoming_effect(effect : CombatEffect):
	# If your custom status resource script implements 'modify_incoming_effect'
	if data.has_method("modify_incoming_effect"):
		# In this case, your status mark script doesn't have gates, so we call it directly,
		# passing 'self' so your script can read live variables like 'current_stacks'!
		data.modify_incoming_effect(effect, self)
		
	# Fallback if you ever create an incoming modifier that needs to bypass everything
	elif data.has_method("_execute_incoming_modification"):
		data._execute_incoming_modification(effect, self)
		
func _execute_incoming_modification(effect: CombatEffect):
	if data.has_method("_execute_incoming_modification"):
		data._execute_incoming_modification(effect, self)
		
# Called on the ATTACKER to modify the raw pool of enemies before range math
func modify_initial_targets(active_candidates: Array[HeroSlot], source: HeroSlot) -> Array[HeroSlot]:
	if data.has_method("modify_initial_targets"):
		return data.modify_initial_targets(active_candidates, source, self)
	return active_candidates

# Called on the DEFENDER to let them alter the pool (e.g., Taunt forcing itself to be targeted)
func modify_defender_final_targets(reachables: Array[HeroSlot], defender_slot: HeroSlot) -> Array[HeroSlot]:
	if data.has_method("modify_defender_final_targets"):
		return data.modify_defender_final_targets(reachables, defender_slot, self)
	return reachables

# Called on the ATTACKER at the very end to scale targets up or down (Cleave, AOE, Snipe)
func modify_attacker_final_targets(resolved_targets: Array[HeroSlot], reachable_pool: Array[HeroSlot]) -> Array[HeroSlot]:
	if data.has_method("modify_attacker_final_targets"):
		return data.modify_attacker_final_targets(resolved_targets, reachable_pool, self)
	return resolved_targets

#Universal Validation Gate
func _check_trigger(current_hook: String, context: CombatContext, trigger_data: Variant):
	var expected_hook_string = Enums.TRIGGER_STRINGS.get(data.trigger_event, "")
	# If it is the current triggering event/combat phase
	if current_hook != expected_hook_string:
		return 
		
	# Execute the payload
	_execute_behavior_payload(context,trigger_data)

func _execute_behavior_payload(context: CombatContext,trigger_data):
	# If the linked data resource asset contains a custom execution payload override, we call it
	if data.has_method("_execute_behavior_payload_override"):
		data._execute_behavior_payload_override(context, self, trigger_data)

func roll_crit_local(checking_hero: Hero, main_action_crit: bool = false) -> bool:
	if data.proc_chance < 1.0 and randf() > data.proc_chance: return false
	var rolled_innate: bool = randf() < checking_hero.get_stat(Enums.StatType.CRIT)
	var critical_to_check: bool = main_action_crit if main_action_crit != false else rolled_innate
	if data.trigger_on_innate_crit and not critical_to_check: return false
	
	return data.force_critical_strike or \
		   (data.trigger_on_innate_crit and critical_to_check) or \
		   (not data.trigger_on_innate_crit and data.proc_chance == 1.0 and rolled_innate)

func create_effect(effect_type: Script, target_slot: HeroSlot, source_slot: HeroSlot) -> CombatEffect:
	var effect = effect_type.new() as CombatEffect
	effect.source = source_slot
	effect.target = target_slot
	effect.effect_owner = owner_hero 
	effect.animation = data.animation
	effect.animation_duration = data.animation_duration
	
	for data_template in data.behaviors_to_apply:
		if data_template != null:
			effect.buffs.append(Behavior.create(data_template))
			
	return effect


##Below we will have functions for every event we want to check
##which means on_hit, on_death, on_taking_damage etc etc.
##Then, we create resources for each behaviorData and define what said behavior is doing on every 
##event.

func get_valid_targets(source: HeroSlot, candidates: Array[HeroSlot]) -> Array[HeroSlot]:
	var reachables = get_reachable_targets(source, candidates)
	return _apply_target_type(reachables, source) 
	
func get_reachable_targets(source: HeroSlot, candidates: Array[HeroSlot]) -> Array[HeroSlot]:
	# Only evaluate slots that actually contain a hero
	var active_candidates = candidates.filter(func(slot): return slot.hero != null)
	
	# --- 1. SELF-TARGETING SHORT-CIRCUIT ---
	if data.target_team == Enums.Team.SELF:
		return [source]

	# Attacker Hook
	for b in owner_hero.get_behaviors():
		if b.has_method("modify_initial_targets"):
			active_candidates = b.call("modify_initial_targets", active_candidates, source)
		
	var r = data.range if data.range > 0 else owner_hero.get_stat(Enums.StatType.RANGE)
	var action_range = owner_hero.get_stat(Enums.StatType.RANGE)
	
	var reachables: Array[HeroSlot] = []
	
	# --- 2. RUN POSITION MATH (Universal for Friends & Enemies) ---
	var is_frontline_alive = func(idx: int) -> bool:
		return active_candidates.any(func(slot): return slot.index == idx)
		
	var frontline = active_candidates.filter(func(slot): return slot.index <= 1)
	var backline = active_candidates.filter(func(slot): return slot.index > 1)
	
	var exposed_backline = backline.filter(func(slot):
		match slot.index:
			2: return not is_frontline_alive.call(0)
			3: return not is_frontline_alive.call(0) and not is_frontline_alive.call(1)
			4: return not is_frontline_alive.call(1)
		return false
	)
	
	# --- CHOOSE REACHABLE POOL BY RANGE ---
	if action_range >= 3:
		# Range 3+: Hits ANY target on the selected team
		reachables = active_candidates
	elif action_range == 2:
		# Range 2: Hits backline first, falls back to frontline if dead
		reachables = backline if not backline.is_empty() else frontline
	else:
		# Range 1: Normal lane protection applies (frontline + exposed backline)
		reachables = frontline + exposed_backline
	
	# Defender Hook (e.g., Taunt) - Right now only applies when targeting enemies
	if data.target_team == Enums.Team.ENEMY:
		for slot in reachables:
			if slot.hero != null:
				for b in slot.hero.get_behaviors():
					if b.has_method("modify_defender_final_targets"):
						reachables = b.call("modify_defender_final_targets", reachables, slot)
				
	return reachables 
	
func _apply_target_type(candidates: Array[HeroSlot], source: HeroSlot) -> Array[HeroSlot]:
	if candidates.is_empty():
		return candidates

	var resolved_targets: Array[HeroSlot] = []

	match data.target_type:
		Enums.Target.ALL:
			# Hits everything available unconditionally (ignores target_count)
			resolved_targets = candidates.duplicate()

		Enums.Target.SINGLE:
			# hit exactly 1, 2, or 3 completely independent random targets, right now this works the same as
			# multi
			var pool = candidates.duplicate()
			pool.shuffle()
			# Clamps to prevent trying to grab more heroes than actually exist in the pool
			var max_hits = clampi(data.target_count, 1, pool.size())
			resolved_targets = pool.slice(0, max_hits)
		## THIS DOESNT WORK RIGHT NOW AS IT SHOULD, or well, the targeting works, but not the
		## simultaneously applied effect. Look into it if needed, otherwise dont use cleave
		Enums.Target.REPEAT:
			if not candidates.is_empty():
				# 1. Lock onto one single primary target completely randomly
				var primary_target = candidates.pick_random()
				
				# 2. Duplicate that EXACT SAME unit into the target queue 'target_count' times
				for i in range(data.target_count):
					resolved_targets.append(primary_target)
		Enums.Target.CLEAVE:
			if candidates.is_empty():
				resolved_targets = []
			else:
				var primary_target = candidates.pick_random()
				resolved_targets.append(primary_target)
				
				if data.target_count > 1:
					var neighbors = _find_adjacent_neighbors(primary_target, candidates)
					neighbors.shuffle() # Randomize left/right sweep direction
					
					var extra_hits = data.target_count - 1
					# Safely clamp using the actual available alive neighbors array size
					var max_extra = clampi(extra_hits, 0, neighbors.size())
					
					for i in range(max_extra):
						resolved_targets.append(neighbors[i])
						
		Enums.Target.MULTI:
			# 1. Safety check: Ensure we actually have living candidates to hit
			if not candidates.is_empty():
				# 2. Loop exactly 'data.target_count' times to build your multi-strike queue
				for i in range(data.target_count):
				# Pick a target out of the full pool completely randomly.
				# Because we don't remove them, the same hero can be picked multiple times!
					var random_target = candidates.pick_random()
					resolved_targets.append(random_target)

	# Attacker Hook
	for b in owner_hero.get_behaviors():
		if b.has_method("modify_attacker_final_targets"):
			resolved_targets = b.call("modify_attacker_final_targets", resolved_targets, candidates)
			
	return resolved_targets

func _find_adjacent_neighbors(primary: HeroSlot, pool: Array[HeroSlot]) -> Array[HeroSlot]:
	var neighbors: Array[HeroSlot] = []
	var p_idx = primary.index
	
	# ---  Frontline is <= 1, Backline is > 1 ---
	var is_primary_frontline = (p_idx <= 1)
	
	for slot in pool:
		if slot == primary: 
			continue
			
		var s_idx = slot.index
		var is_slot_frontline = (s_idx <= 1)
		
		# --- ROW CHECK: Both primary and candidate must be in the same line context ---
		if is_primary_frontline == is_slot_frontline:
			# --- DISTANCE CHECK: Must be exactly 1 slot away horizontally ---
			if abs(s_idx - p_idx) == 1:
				neighbors.append(slot)
				
	return neighbors
	
func get_distance(source: HeroSlot, target_slot: HeroSlot) -> int:
	# Self targeting is always 0 distance
	if data.target_team == Enums.Team.SELF or source == target_slot:
		return 0
	
	# Frontline (indexes 0, 1) is distance 1. Backline (2, 3, 4) is distance 2.
	return 1 if target_slot.index <= 1 else 2
