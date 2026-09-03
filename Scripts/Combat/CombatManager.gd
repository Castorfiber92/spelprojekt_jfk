extends Node
class_name CombatManager

@export var combat_ui : CombatUI
##hero is the key, slot is the value
var hero_to_slot_map : Dictionary = {}
var player_slots : Array[HeroSlot]
var enemy_slots : Array[HeroSlot]
@export var active_slot : HeroSlot

const EFFECT_BUFFER_DURATION: float = 0.3
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
	current_phase = new_value
	if combat_ui and combat_ui.phase_ui:
		var string = Enums.CombatPhase.keys()[current_phase]
		combat_ui.phase_ui.text = string

func _ready() -> void:
	GameEvents.effect_created.connect(_on_effect_requested)
	create_slots()
	await wait_for_input("ui_accept")
	
	# The manager announces globally that the match has officially begun!
	GameEvents.battle_started.emit(self)
	
	await wait_for_stack_to_clear()
	run_combat_loop()

func run_combat_loop():
	while combat_active:
		var next_hero_slot = get_next_acting_hero()
		
		# If no heroes can act, the round is officially over!
		if next_hero_slot == null:
			# Shouts globally: This tells all active status items to tick natively!
			GameEvents.round_ended.emit(self)
			
			# Wait for any status damage or end-of-round heals to fully resolve
			await wait_for_stack_to_clear()
			print("Press SPACE to start the next round...")
			await wait_for_input("ui_accept")
			print("Next round started!")
			reset_round()
			await wait_for_stack_to_clear()
			continue # Restart the loop for the new round
			
		active_slot = next_hero_slot
		
		# Linear execution: Pauses completely here until the turn resolves
		await execute_turn(active_slot)
		await wait_for_stack_to_clear()
		await get_tree().create_timer(0.3).timeout
		
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
		if slot and slot.hero != null and not slot.hero.has_acted:
			candidates.append(slot)
	
	if candidates.is_empty(): return null
		
	candidates.shuffle()
	candidates.sort_custom(func(a, b): return a.hero.get_stat(Enums.StatType.SPEED) > b.hero.get_stat(Enums.StatType.SPEED))
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
		
		# 1. Pipeline Interceptions (Filters incoming/outgoing stats)
		process_effect(effect)
		
		# 2. Pure Polymorphic Execution (Every effect checks its own target rules!)
		effect.execute(self)       
		
		# 3. Chronological Visual Presentation Sequence
		await effect.present(self)  
		
		# 4. Safe Post-Execution Reaping & Visual Updates
		check_and_process_deaths()
		update_UI()
		
		await get_tree().process_frame
		await get_tree().create_timer(EFFECT_BUFFER_DURATION).timeout
		
	is_processing = false

func process_effect(effect: CombatEffect):
	# 1. Outgoing Interception Valve: Evaluates attacker passives
	if effect.effect_owner != null and is_instance_valid(effect.effect_owner):
		for b in effect.effect_owner.active_passives:
			b.modify_outgoing_effect(effect)
				
	# 2. Incoming Interception Valve: Evaluates defender passives (Armor, Mark)
	if effect.target != null and is_instance_valid(effect.target) and effect.target.hero != null:
		for b in effect.target.hero.active_passives:
			b.modify_incoming_effect(effect)
			
func check_and_process_deaths() -> void:
	var deaths_to_process: Array[DeathEventData] = []
	var all_slots = player_slots + enemy_slots
	
	for slot in all_slots:
		if slot and slot.hero and slot.hero.current_HP <= 0:
			var death_snapshot = DeathEventData.new(slot.hero, slot)
			deaths_to_process.append(death_snapshot)
			
	if deaths_to_process.is_empty():
		return

	# ==============================================================================
	# STEP 1: PUSH DEATH TRIGGERS FIRST (While layout relationships are 100% valid!)
	# ==============================================================================
	for death in deaths_to_process:
		# Passes the original valid slot container as the historical variant payload
		death.dead_hero.trigger_behavior_event(Enums.TriggerEvent.ON_DEATH, death.original_slot, self)
		print("Pushed death trigger for ", death.dead_hero.hero_data.name)
		
	# ==============================================================================
	# STEP 2: SEVER RELATIONSHIPS (Now that all passives have safely executed)
	# ==============================================================================
	for death in deaths_to_process:
		hero_to_slot_map.erase(death.dead_hero)
		death.original_slot.hero = null 
		death.original_slot.update_info() 

	# ==============================================================================
	# STEP 3: MEMORY GARBAGE DISPOSAL
	# ==============================================================================
	for death in deaths_to_process:
		var dead_hero = death.dead_hero
		if is_instance_valid(dead_hero):
			if dead_hero.team == Enums.Team.ENEMY:
				dead_hero.queue_free()

func execute_turn(slot: HeroSlot):
	print("New turn for ", slot.hero.hero_data.name)
	active_slot = slot
	await get_tree().process_frame
	# PHASE 1: PRE_TURN
	current_phase = Enums.CombatPhase.PRE_TURN
	GameEvents.turn_started.emit(slot, self)
	await wait_for_stack_to_clear()
	if not is_instance_valid(slot.hero): return
	
	# Status verification
	if not slot.hero.can_act():
		print(slot.hero.hero_data.name, " is incapacitated and skips their turn!")
		GameEvents.turn_ended.emit(slot, self)
		await wait_for_stack_to_clear()
		return
		
	# PHASE 2: BEFORE_ACT
	current_phase = Enums.CombatPhase.BEFORE_ACT
	await wait_for_stack_to_clear()
	if not is_instance_valid(slot.hero): return
	
	# PHASE 3: EXECUTE
	current_phase = Enums.CombatPhase.EXECUTE
	GameEvents.action_execution_requested.emit(slot, self)
	await wait_for_stack_to_clear()
	
	if is_instance_valid(slot.hero):
		slot.hero.has_acted = true
	else:
		return
		
	# PHASE 4: AFTER_ACT
	current_phase = Enums.CombatPhase.AFTER_ACT
	await wait_for_stack_to_clear()
	if not is_instance_valid(slot.hero): return
	
	# PHASE 5: POST_TURN
	GameEvents.turn_ended.emit(slot, self)
	await wait_for_stack_to_clear()

func wait_for_stack_to_clear():
	if not is_processing and not effect_stack.is_empty():
		await process_stack()
	while is_processing or not effect_stack.is_empty():
		await get_tree().process_frame


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

func clear_highlights():
	for i in player_slots:
		i.cleanup()
	for i in enemy_slots:
		i.cleanup()
	
func get_enemy_slots(acting_team: Enums.Team) -> Array[HeroSlot]:
	var raw_slots = enemy_slots if acting_team == Enums.Team.FRIEND else player_slots
	return raw_slots.filter(func(slot): return slot != null and slot.hero != null and slot.hero.current_HP > 0)

func get_friendly_slots(acting_team: Enums.Team) -> Array[HeroSlot]:
	var raw_slots = player_slots if acting_team == Enums.Team.FRIEND else enemy_slots
	return raw_slots.filter(func(slot): return slot != null and slot.hero != null and slot.hero.current_HP > 0)

func reset_round():
	for slot in hero_to_slot_map.values():
		slot.hero.has_acted = false


func create_slots():
	load_party(PlayerData.player_party, combat_ui.player_party, player_slots, Enums.Team.FRIEND)
	if RunManager.current_encounter == null:
		printerr("CombatManager: No active encounter found!")
		return
	load_party(RunManager.current_encounter.enemy_team, combat_ui.enemy_party, enemy_slots, Enums.Team.ENEMY)
	
func load_party(party_data: Array, ui_parent: Node, target_slots_array: Array[HeroSlot], team_enum: Enums.Team):
	var frontline_ui = ui_parent.get_node("Frontline")
	var backline_ui = ui_parent.get_node("Backline")
	
	for i in range(party_data.size()):
		var slot: HeroSlot = Preloads.hero_slot.instantiate()
		slot.index = i 
		target_slots_array.append(slot)
		
		if i <= 1: 
			frontline_ui.add_child(slot)
		else: 
			backline_ui.add_child(slot)
		
		var data = party_data[i]
		if data == null:
			slot.hero = null
			slot.update_info()
		else:
			spawn_and_assign_hero(data, slot, team_enum)

func add_hero(slot : HeroSlot, hero : Hero):
	if slot.hero != null: 
		remove_hero(slot)
		
	# FIXED: Safety orphan check. If this hero node is still gripped by an old parent 
	# from a previous match, we cleanly unparent it before placing it in the new slot tree!
	if hero.get_parent() != null:
		hero.get_parent().remove_child(hero)
		
	slot.hero = hero
	slot.add_child(hero)
	
	slot.play_animation("idle")
	hero_to_slot_map[hero] = slot
	slot.update_info()

func remove_hero(slot: HeroSlot):
	if slot.hero == null:
		return
		
	# FIXED: Cleanly unparent the node from the slot right here.
	# This ensures that traveling heroes are free to be re-parented in the next battle!
	var hero_node = slot.hero
	if hero_node.get_parent() == slot:
		slot.remove_child(hero_node)
		
	hero_to_slot_map.erase(hero_node)
	slot.hero = null
	slot.update_info()
	
func spawn_and_assign_hero(hero_source: Variant, slot: HeroSlot, team: Enums.Team) -> void:
	var hero: Hero
	if hero_source is Hero:
		hero = hero_source as Hero
		hero.prepare_for_combat()
	elif hero_source is HeroData:
		hero = Hero.create(hero_source)
	else:
		return
	
	hero.team = team
	
	# We only lock their action out if they were summoned during a turn phase 
	# where the active acting slot has ALREADY finished executing its profile.
	if is_processing and active_slot != null and active_slot.hero != null and active_slot.hero.has_acted:
		hero.has_acted = true
	else:
		hero.has_acted = false
		
	add_hero(slot, hero)

func win_combat():
	await wait_for_input("ui_accept")
	for hero in PlayerData.player_party:
		if hero != null and hero.get_parent() != null: 
			hero.get_parent().remove_child(hero)
	get_tree().change_scene_to_file("res://Scripts/Overworld/OverworldManager.tscn")
	
func lose_combat():
	await wait_for_input("ui_accept")
	for hero in PlayerData.player_party:
		if hero != null and hero.get_parent() != null: 
			hero.get_parent().remove_child(hero)
	get_tree().change_scene_to_file("res://Scripts/Overworld/OverworldManager.tscn")


func restart_combat_with_new_enemies():
	if RunManager.current_encounter == null:
		printerr("CombatManager: Cannot restart because current_encounter is missing!")
		return
		
	print("CombatManager: Discarding match and regenerating board layout...")
	
	# 1. Capture the structural type of the battle before discarding it
	var active_battle_type = RunManager.current_encounter.encounter_type
	
	# 2. SIGNAL CLEANUP: Cleanly disconnect only the local combat-death signal!
	for slot in player_slots:
		if is_instance_valid(slot) and is_instance_valid(slot.hero):
			var current_player_hero = slot.hero
			var die_callable = remove_hero.bind(slot)
				
			# THE ONLY CHANGE: Safely detach your player heroes from the slot trees!
			# This protects them from queue_free(), keeping your PlayerData 100% safe in memory.
			if current_player_hero.get_parent() == slot:
				slot.remove_child(current_player_hero)
				
	# 3. CLEAN REAP: Clear out live variables and state machines
	effect_stack.clear()
	is_processing = false
	combat_active = true 
	
	# 4. SEVER RELATIONSHIPS: Erase tracker memory data completely
	hero_to_slot_map.clear()
	
	# 5. DESTROY VISUAL NODES: Completely free the old slot scenes from memory
	# Your player heroes are now safely unparented, so they are not destroyed!
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
