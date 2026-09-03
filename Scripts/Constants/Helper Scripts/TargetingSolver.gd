class_name TargetingSolver

## Primary Entry Point: Resolves team allocations, lane ranges, and target formats
static func resolve_targets(behavior: Behavior, source_slot: HeroSlot, manager: CombatManager) -> Array[HeroSlot]:
	var candidates: Array[HeroSlot] = []
	var team = behavior.owner_hero.team
	
	match behavior.data.target_team:
		Enums.Team.SELF: 
			return [source_slot]
		Enums.Team.FRIEND: 
			candidates = manager.get_friendly_slots(team)
		Enums.Team.ENEMY: 
			candidates = manager.get_enemy_slots(team)
			
	if candidates.is_empty():
		return [] as Array[HeroSlot]
		
	# 1. Evaluate range rules and row protections
	var reachables = filter_by_range(candidates, source_slot, behavior)
	
	# 2. Run Defender Modifiers (e.g., Taunt overrides) if targeting an enemy team
	if behavior.data.target_team == Enums.Team.ENEMY:
		reachables = apply_defender_hooks(reachables)
		
	# 3. Apply the structural target type profiles (SINGLE, CLEAVE, MULTI, REPEAT, ALL)
	return apply_target_type(reachables, source_slot, behavior.data)


## Spatial Grid Math: Handles frontline lane blocks and distance restrictions
static func filter_by_range(candidates: Array[HeroSlot], source_slot: HeroSlot, behavior: Behavior) -> Array[HeroSlot]:
	var active_candidates = candidates.filter(func(slot): return slot and slot.hero != null)
	var action_range = behavior.owner_hero.get_stat(Enums.StatType.RANGE)
	
	var frontline = active_candidates.filter(func(slot): return slot.index <= 1)
	var backline = active_candidates.filter(func(slot): return slot.index > 1)
	
	var is_front_alive = func(idx: int) -> bool:
		return active_candidates.any(func(slot): return slot.index == idx)
		
	# Normal range-1 position cover rules
	var exposed_backline = backline.filter(func(slot):
		match slot.index:
			2: return not is_front_alive.call(0)
			3: return not is_front_alive.call(0) and not is_front_alive.call(1)
			4: return not is_front_alive.call(1)
		return false
	)
	
	if action_range >= 3:
		return active_candidates
	elif action_range == 2:
		return backline if not backline.is_empty() else frontline
		
	return frontline + exposed_backline


## Defender Hook Interceptor: Allows target slots to attract focus (Taunts)
static func apply_defender_hooks(reachables: Array[HeroSlot]) -> Array[HeroSlot]:
	var updated_pool = reachables.duplicate()
	for slot in reachables:
		if slot and slot.hero:
			# If a defender's passive contains a special target redirection hook
			for b in slot.hero.active_passives:
				if b.data.has_method("modify_defender_final_targets"):
					updated_pool = b.data.modify_defender_final_targets(updated_pool, slot, b)
	return updated_pool


## Layout Slicing Engine: Shapes final target clusters
static func apply_target_type(pool: Array[HeroSlot], source_slot: HeroSlot, data: BehaviorData) -> Array[HeroSlot]:
	if pool.is_empty(): 
		return [] as Array[HeroSlot]
		
	var resolved: Array[HeroSlot] = []
	
	match data.target_type:
		Enums.Target.ALL:
			resolved = pool.duplicate()
			
		Enums.Target.SINGLE:
			# DISTINCT TARGETS ONLY: Grabs up to 'target_count' independent heroes
			var candidates = pool.duplicate()
			candidates.shuffle()
			var count = clampi(data.target_count, 1, candidates.size())
			resolved = candidates.slice(0, count)
			
		Enums.Target.MULTI:
			# OVERLAPPING TOTAL STRIKES: Can pick and double-hit the same unit multiple times
			for i in range(data.target_count):
				resolved.append(pool.pick_random())
				
		Enums.Target.REPEAT:
			# SINGLE LOCK-ON STRIKE: Repeats the exact same chosen unit 'target_count' times
			var choice = pool.pick_random()
			for i in range(data.target_count):
				resolved.append(choice)
				
		Enums.Target.CLEAVE:
			# PRIMARY FOCUS + HORIZONTAL ROW NEIGHBORS
			var primary = pool.pick_random()
			resolved.append(primary)
			if data.target_count > 1:
				var neighbors = find_neighbors(primary, pool)
				neighbors.shuffle()
				var extra_hits = clampi(data.target_count - 1, 0, neighbors.size())
				for i in range(extra_hits):
					resolved.append(neighbors[i])
					
	# Attacker final-sweep hook modifications (kept as-is)
	if source_slot.hero:
		for b in source_slot.hero.active_passives:
			if b.data.has_method("modify_attacker_final_targets"):
				resolved = b.data.modify_attacker_final_targets(resolved, pool, b)
				
	return resolved


## Horizontal Proximity Tool: Checks for left/right flanking positions
static func find_neighbors(primary: HeroSlot, pool: Array[HeroSlot]) -> Array[HeroSlot]:
	var neighbors: Array[HeroSlot] = []
	var p_idx = primary.index
	var is_p_front = (p_idx <= 1)
	
	for slot in pool:
		if slot == primary: continue
		if is_p_front == (slot.index <= 1): # Must be in the identical row context
			if abs(slot.index - p_idx) == 1: # Must be adjacent
				neighbors.append(slot)
	return neighbors
