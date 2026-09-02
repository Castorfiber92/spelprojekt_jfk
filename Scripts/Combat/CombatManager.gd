extends Node
class_name CombatManager

@export var combat_ui : CombatUI
##hero is the key, slot is the value
var hero_to_slot_map : Dictionary = {}
var player_slots : Array[HeroSlot]
var enemy_slots : Array[HeroSlot]
@export var active_slot : HeroSlot

# For death handling
class DeathEventData:
	var dead_hero: Hero
	var original_slot: HeroSlot
	
	func _init(hero: Hero, slot: HeroSlot) -> void:
		self.dead_hero = hero
		self.original_slot = slot

## Stack variables
var effect_stack: Array[CombatEffect] = []
var is_processing: bool = false
var combat_active: bool = true

var current_phase : Enums.CombatPhase : set = update_phase_UI

func update_phase_UI(new_value: Enums.CombatPhase) -> void:
	var string = Enums.CombatPhase.keys()[current_phase]
	combat_ui.phase_ui.text = string
	current_phase = new_value

func _ready() -> void:
	GameEvents.effect_created.connect(_on_effect_requested)
	create_slots()
	await wait_for_input("ui_accept")
	## For testing purposes
	var all_slots = player_slots.duplicate()
	all_slots.append_array(enemy_slots)
	all_slots.shuffle()
	for slot in all_slots:
		if slot and slot.hero != null:
			slot.hero.trigger_behavior_event(Enums.TriggerEvent.ON_START_OF_BATTLE, slot, [] as Array[HeroSlot], self)
	await wait_for_stack_to_clear()
	## Continue
	run_combat_loop()

func run_combat_loop():
	while combat_active:
		var next_hero_slot = get_next_acting_hero()
		
		# If no heroes can act, the round is over!
		if next_hero_slot == null:
			# 1. Trigger the round end behavior event for all living heroes
			var all_slots = player_slots + enemy_slots
			var living_slots = all_slots.filter(func(slot): return slot and slot.hero != null)
			# Sort it via speed - fastest pops first
			living_slots.sort_custom(func(a, b): return a.hero.get_stat(Enums.StatType.SPEED) > b.hero.get_stat(Enums.StatType.SPEED))
			for slot in living_slots:
				if slot and slot.hero != null:
					slot.hero.trigger_behavior_event(Enums.TriggerEvent.ON_ROUND_END, slot, [] as Array[HeroSlot], self)
			
			# 2. Wait for any status damage, end-of-round heals, or triggers to completely resolve
			await wait_for_stack_to_clear()
			print("Press SPACE to start the next round...")
			await wait_for_input("ui_accept")
			print("Next round started!")
			reset_round()
			await wait_for_stack_to_clear()
			continue # Restart the loop for the new round
			
		active_slot = next_hero_slot
		
		# Linear execution: Code completely pauses here until the turn and all cascades finish
		await execute_turn(active_slot)
		await wait_for_stack_to_clear()
		# --- ADDED FOR TESTING: PACING DELAY BETWEEN ACTIONS ---
		# Adjust the '0.5' to make the pause longer (e.g., 1.0) or shorter (e.g., 0.2)
		await get_tree().create_timer(0.3).timeout
		# -------------------------------------------------------
		
		# Clean up this specific turn completely before going to the top of the while-loop
		_wrap_up_turn(active_slot.hero)
		update_UI()

func wait_for_input(action_name: String):
	# This loop 'pauses' the logic without freezing the game engine
	while true:
		# Wait for exactly one frame to pass
		await get_tree().process_frame
		
		if not is_inside_tree():
			return
		# Check if the specific action (Space/Enter) was just pressed
		if Input.is_action_just_pressed(action_name):
			return # This 'resolves' the await in the calling function
			
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("combat_restart"):
		restart_combat_with_new_enemies()
			
# BELOW IS FOR TESTING ONLY
func emergency_exit_to_overworld() -> void:
	await get_tree().process_frame
	print("Combat Manager: Shutting down loops for safe escape...")
	
	# 1. Flip your loop variables to false to instantly break all active 'while true' loops
	combat_active = false
	is_processing = false
	effect_stack.clear()
	
	# 2. Swap back to the overworld map scene safely
	get_tree().change_scene_to_file("res://Scripts/Overworld/OverworldManager.tscn")

func get_next_acting_hero() -> HeroSlot:
	var candidates : Array[HeroSlot] = []
	var all_slots = player_slots + enemy_slots
	for slot in all_slots:
		# Ensure the slot exists, contains a living hero, and that hero hasn't acted yet
		if slot and slot.hero != null and not slot.hero.has_acted:
			candidates.append(slot)
	
	if candidates.is_empty():
		return null
		
	candidates.shuffle()
	candidates.sort_custom(func(a, b): return a.hero.current_speed > b.hero.current_speed)
	return candidates[0]
	
func update_UI():
	for slot in hero_to_slot_map.values():
		slot.update_info()

func _on_effect_requested(new_effect: CombatEffect):
	effect_stack.append(new_effect)
	if is_processing:
		return
	process_stack()

func process_stack() -> void:
	is_processing = true
	
	while not effect_stack.is_empty():
		var effect = effect_stack.pop_front()
		
		# Safety fallback check
		if effect.target != null: 
			if effect.target.hero == null or not hero_to_slot_map.has(effect.target.hero):
				printerr("Skipping effect: Target hero is no longer on the battlefield.")
				continue
			
		# 1. Pipeline (Modifiers are calculated first)
		process_effect(effect)
		
		# 2. Polymorphic Execution & Visual Sequence Execution
		var execution_result = effect.execute(self)       
		await effect.present(self)  # Orchestrated graphics presentation sequences
		if execution_result is CombatContext:
			var dealt_damage = execution_result.get_damage_dealt_to(effect.target)
	
			effect.target.hero.trigger_behavior_event(
					Enums.TriggerEvent.ON_DAMAGE_TAKEN, 
					effect.source, 
					[] as Array[HeroSlot], 
					self
				)
		await get_tree().process_frame
		check_and_process_deaths()
		await get_tree().process_frame
		update_UI()

	is_processing = false

func check_and_process_deaths() -> void:
	var deaths_to_process: Array[DeathEventData] = []
	var all_slots = player_slots + enemy_slots
	
	# Step 1: Scan and create snapshots of all dead units simultaneously
	for slot in all_slots:
		if slot and slot.hero and slot.hero.current_HP <= 0:
			var death_snapshot = DeathEventData.new(slot.hero, slot)
			deaths_to_process.append(death_snapshot)
			
	if deaths_to_process.is_empty():
		return
		
	# Step 2: Instant Board Clear. 
	# They are gone from the map and slots BEFORE any triggers activate.
	# Other triggered skills on the stack cannot target them.
	for death in deaths_to_process:
		hero_to_slot_map.erase(death.dead_hero)
		death.original_slot.hero = null 
		death.original_slot.update_info() 

	# Step 3: Populate the Stack
	# We loop through our snapshots. The behaviors read the location from the payload.
	for death in deaths_to_process:
		# Pass death.original_slot straight into the trigger!
		# If it's a summon behavior, it uses this explicit slot reference.
		death.dead_hero.trigger_behavior_event(
			Enums.TriggerEvent.ON_DEATH, 
			death.original_slot, 
			[] as Array[HeroSlot], 
			self
		)
		print("Pushed death trigger to stack for ", death.dead_hero.hero_data.name, " from slot ", death.original_slot.name)
		
	# Step 4: Yield to your MTG/Hearthstone stack processor
	# This lets all the queued up deathrattles/summons fully resolve
	#await wait_for_stack_to_clear()
	
	# Step 5: Final Memory Cleanup
	for death in deaths_to_process:
		var dead_hero = death.dead_hero
		if is_instance_valid(dead_hero):
			if dead_hero.team == Enums.Team.ENEMY:
				dead_hero.queue_free()
			else:
				# Hide player heroes so they don't visually linger
				dead_hero.visible = false 
				print(dead_hero.hero_data.name, " remains in memory as defeated.")

func execute_turn(slot: HeroSlot):
	print("New turn for ", slot.hero.hero_data.name)
	
	# PHASE 1: PRE_TURN
	current_phase = Enums.CombatPhase.PRE_TURN
	slot.hero.trigger_behavior_event(Enums.TriggerEvent.ON_TURN_START, slot, [], self) 
	await wait_for_stack_to_clear()
	if not is_instance_valid(slot.hero): return
	
	# Status verification
	if not slot.hero.can_act():
		print(slot.hero.hero_data.name, " is incapacitated and skips their turn!")
		slot.hero.trigger_behavior_event(Enums.TriggerEvent.ON_TURN_END, slot, [], self)
		await wait_for_stack_to_clear()
		return
		
	# PHASE 2: BEFORE_ACT
	current_phase = Enums.CombatPhase.BEFORE_ACT
	#slot.hero.trigger_behavior_event("on_before_act", slot, [], self)
	await wait_for_stack_to_clear()
	if not is_instance_valid(slot.hero): return
	# PHASE 3: EXECUTE
	current_phase = Enums.CombatPhase.EXECUTE
	
	# We pass an empty target array []. The hero's active attack behavior
	# will resolve its targets automatically using the behavior's range rules
	slot.hero.trigger_behavior_event(Enums.TriggerEvent.ON_EXECUTE_ACTION, slot, [], self)
	await wait_for_stack_to_clear()
	if is_instance_valid(slot.hero):
		slot.hero.has_acted = true
	else:
		return
	# PHASE 4: AFTER_ACT
	current_phase = Enums.CombatPhase.AFTER_ACT
	#slot.hero.trigger_behavior_event(Enums.TriggerEvent.on, slot, [], self)
	await wait_for_stack_to_clear()
	if not is_instance_valid(slot.hero): return
	# PHASE 5: POST_TURN
	slot.hero.trigger_behavior_event(Enums.TriggerEvent.ON_TURN_END, slot, [], self)
	await wait_for_stack_to_clear()

func wait_for_stack_to_clear():
	# If items exist and we aren't processing, start the loop intentionally
	if not is_processing and not effect_stack.is_empty():
		await process_stack()
	
	# Keep waiting if an active presentation is rendering on screen
	while is_processing or not effect_stack.is_empty():
		await get_tree().process_frame
	## THe commented is the old, not sure which is best
	#while is_processing or not effect_stack.is_empty():
		#await get_tree().process_frame

func _wrap_up_turn(hero: Hero):
	if hero:
		hero.has_acted = true
	current_phase = Enums.CombatPhase.IDLE
	clear_highlights()
	
	var player_defeated = player_slots.all(func(slot): return slot.hero == null)
	if player_defeated:
		combat_active = false
		lose_combat()
		return
		
	var enemy_defeated = enemy_slots.all(func(slot): return slot.hero == null)
	if enemy_defeated:
		combat_active = false
		win_combat()
		return

func process_effect(effect: CombatEffect):
	# 1. We check the attacker's behaviors and modify the outgoing effect
	# (Items, Strength buffs, Crit chances, etc.)
	if effect.effect_owner != null and is_instance_valid(effect.effect_owner):
		for b in effect.effect_owner.get_behaviors():
			# No string check needed! Every runtime behavior safely handles this now.
			if b.owner_hero == effect.effect_owner:
				b.modify_outgoing_effect(effect)
	# 2. We check the target's behaviors and modify the incoming effect
	# (Armor, Shields, Damage Reduction, etc.)
	if effect.target != null and is_instance_valid(effect.target):
		for b in effect.target.hero.get_behaviors():
			if b.owner_hero == effect.target.hero:
			# No string check needed!
				b.modify_incoming_effect(effect)

func clear_highlights():
	for i in player_slots:
		i.cleanup()
	for i in enemy_slots:
		i.cleanup()
	
func get_enemy_slots(acting_team: Enums.Team) -> Array[HeroSlot]:
	var raw_slots = enemy_slots if acting_team == Enums.Team.FRIEND else player_slots
	
	return raw_slots.filter(func(slot): 
		return slot != null and slot.hero != null and slot.hero.current_HP > 0
	)

func get_friendly_slots(acting_team: Enums.Team) -> Array[HeroSlot]:
	var raw_slots = player_slots if acting_team == Enums.Team.FRIEND else enemy_slots
	
	return raw_slots.filter(func(slot): 
		return slot != null and slot.hero != null and slot.hero.current_HP > 0
	)

func reset_round():
	for slot in hero_to_slot_map.values():
		slot.hero.has_acted = false


func create_slots():
	## Here we will create slots according to the playerparty 
	## and according to what type of enemies we want to generate.
	
	# Pass PlayerData.player_party directly because it now holds the live Hero nodes
	load_party(PlayerData.player_party, combat_ui.player_party, player_slots, Enums.Team.FRIEND)
	if RunManager.current_encounter == null:
		printerr("CombatManager: No active encounter found in RunManager! Cannot spawn enemies.")
		return
	var active_enemy_team: Array[HeroData] = RunManager.current_encounter.enemy_team
	load_party(active_enemy_team, combat_ui.enemy_party, enemy_slots, Enums.Team.ENEMY)
	
func load_party(party_data: Array, ui_parent: Node, target_slots_array: Array[HeroSlot], team_enum: Enums.Team):
	var frontline_ui = ui_parent.get_node("Frontline")
	var backline_ui = ui_parent.get_node("Backline")
	
	for i in range(party_data.size()):
		# 1. Create and anchor the empty layout slot
		var slot: HeroSlot = Preloads.hero_slot.instantiate()
		slot.index = i 
		target_slots_array.append(slot)
		
		if i <= 1:
			frontline_ui.add_child(slot)
		else:
			backline_ui.add_child(slot)
		
		# 2. Populate the slot if data exists
		var data = party_data[i]
		if data == null:
			slot.hero = null
			slot.update_info()
		else:
			spawn_and_assign_hero(data, slot, team_enum)

func add_hero(slot : HeroSlot, hero : Hero):
	if slot.hero != null:
		push_warning("Overwriting an occupied slot! Forcing removal of old hero.")
		# Cleanly disconnect the living hero before removing them
		var old_callable = remove_hero.bind(slot)
		if slot.hero.has_died.is_connected(old_callable):
			slot.hero.has_died.disconnect(old_callable)
	
		remove_hero(slot)
	slot.hero = hero
	slot.play_animation("idle")
	##Map the slot/hero combination to the dictionary
	hero_to_slot_map[hero] = slot
	##Update the ui of the slot
	slot.update_info()
	
	# Connect signals
	hero.behavior_removed.connect(slot.update_buff_slots, CONNECT_REFERENCE_COUNTED)
	hero.has_died.connect(remove_hero.bind(slot), CONNECT_ONE_SHOT)

func remove_hero(slot: HeroSlot):
	if slot.hero == null:
		return
		
	hero_to_slot_map.erase(slot.hero)
	slot.hero = null
	slot.update_info()
	
func spawn_and_assign_hero(hero_source: Variant, slot: HeroSlot, team: Enums.Team) -> void:
	var hero: Hero
	
	if hero_source is Hero:
		# Comes from player data and carries persisting data
		hero = hero_source as Hero
		hero.prepare_for_combat()
	elif hero_source is HeroData:
		# FIX: Pass 'hero_source' to your engine-safe factory method
		hero = Hero.create(hero_source)
	else:
		printerr("CombatManager: Attempted to spawn a hero from an invalid source type!")
		return
	
	# Assign their active battlefield team alignment
	hero.team = team
	# If the combat stack loop is actively processing a round, 
	# we flag the new minion immediately so it skips the current round's action phase.
	if is_processing:
		hero.has_acted = true
	# Bind them securely to the target HeroSlot node and tracker dictionaries
	add_hero(slot, hero)

func win_combat():
	print("You win the battle!")
	await wait_for_input("ui_accept")
	for hero in PlayerData.player_party:
		# Verify the hero exists and is currently attached to the combat screen tree
		if hero != null and hero.get_parent() != null:
			# Cleanly detach them so they are free agents for the overworld map
			hero.get_parent().remove_child(hero)
	get_tree().change_scene_to_file("res://Scripts/Overworld/OverworldManager.tscn")
	
func lose_combat():
	print("You lose the battle!")
	await wait_for_input("ui_accept")
	for hero in PlayerData.player_party:
		# Verify the hero exists and is currently attached to the combat screen tree
		if hero != null and hero.get_parent() != null:
			# Cleanly detach them so they are free agents for the overworld map
			hero.get_parent().remove_child(hero)
	get_tree().change_scene_to_file("res://Scripts/Overworld/OverworldManager.tscn")
func initialize_combat():
	pass
	
func restart_combat_with_new_enemies():
	if RunManager.current_encounter == null:
		printerr("CombatManager: Cannot restart because current_encounter is missing!")
		return
		
	print("CombatManager: Discarding match and regenerating board layout...")
	
	# 1. Capture the structural type of the battle before discarding it
	# Check whether your CombatComposition resource calls it 'battle_type' or 'action_profile'
	var active_battle_type = RunManager.current_encounter.encounter_type
	
	# 2. SIGNAL CLEANUP: Cleanly disconnect persistent player heroes before wiping the slots!
	# This prevents the 'Signal already connected' error and stops reference corruption.
	for slot in player_slots:
		if is_instance_valid(slot) and is_instance_valid(slot.hero):
			var current_player_hero = slot.hero
			
			# Safe disconnection tracking matching your exact add_hero() connection types
			var die_callable = remove_hero.bind(slot)
			if current_player_hero.has_died.is_connected(die_callable):
				current_player_hero.has_died.disconnect(die_callable)
				
			if current_player_hero.behavior_removed.is_connected(slot.update_buff_slots):
				current_player_hero.behavior_removed.disconnect(slot.update_buff_slots)
				
	# 3. CLEAN REAP: Clear out live variables and state machines
	if "effect_stack" in self:
		effect_stack.clear()
	is_processing = false
	combat_active = true 
	
	# 4. SEVER RELATIONSHIPS: Erase tracker memory data completely
	hero_to_slot_map.clear()
	
	# 5. DESTROY VISUAL NODES: Completely free the old slot scenes from memory
	for slot in player_slots:
		if is_instance_valid(slot):
			slot.queue_free()
	player_slots.clear()
	
	for slot in enemy_slots:
		if is_instance_valid(slot):
			slot.queue_free()
	enemy_slots.clear()
	
	# 6. GENERATE NEW ENCOUNTER: Pass the battle type back to your RunManager
	RunManager.roll_next_encounter(active_battle_type)
	
	if RunManager.current_encounter == null:
		printerr("CombatManager: RunManager failed to roll a new encounter. Aborting reset.")
		return
	
	# 7. RE-INITIALIZE: Yield one single frame to let old children clean up, 
	# then spawn the fresh teams onto the battlefield canvas
	await get_tree().process_frame
	
	create_slots()
	update_UI()
	
	print("CombatManager: Fresh encounter [", RunManager.current_encounter.encounter_name, "] successfully deployed!")
