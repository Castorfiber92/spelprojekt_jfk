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
	var context = CombatContext.new(null, [], self)
	GameEvents.combat_event.emit(Enums.TriggerEvent.ON_START_OF_BATTLE, context)
	
	await wait_for_stack_to_clear()
	run_combat_loop()

func run_combat_loop():
	while combat_active:
		var next_hero_slot = get_next_acting_hero()
		
		# If no heroes can act, the round is officially over!
		if next_hero_slot == null:
			# Shouts globally: This tells all active status items to tick natively!
			var context = CombatContext.new(null, [], self)
			GameEvents.combat_event.emit(Enums.TriggerEvent.ON_ROUND_END, context)
			
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
	for hero in PlayerData.player_party:
		cleanup_all_slots()
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
	candidates.sort_custom(func(a, b): 
		return int(a.hero.get_current_stat(Enums.StatType.SPEED)) > int(b.hero.get_current_stat(Enums.StatType.SPEED))
	)
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
	if effect.effect_owner != null:
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
		if slot and slot.hero and slot.hero.get_current_stat(Enums.StatType.HP) <= 0:
			var death_snapshot = DeathEventData.new(slot.hero, slot)
			deaths_to_process.append(death_snapshot)
			
	if deaths_to_process.is_empty():
		return

	# push death triggers

	for death in deaths_to_process:
	# Trigger self-death passives on the dying hero only
		var self_context = CombatContext.new(death.original_slot, [], self)
		GameEvents.combat_event.emit(Enums.TriggerEvent.ON_DEATH, self_context)
	
	# Broadcast to all other heroes/items on the board, by setting source as null and target as something to
	# bypass the self-triggering behaviors.
		var global_context = CombatContext.new(null, [death.original_slot], self)
		GameEvents.combat_event.emit(Enums.TriggerEvent.ON_ANY_DEATH, global_context)
	
	# Clean up and "kill" the hero
	for death in deaths_to_process:
		death.dead_hero.deactivate()
		hero_to_slot_map.erase(death.dead_hero)
		death.original_slot.hero = null 
		death.original_slot.update_info() 


func execute_turn(slot: HeroSlot) -> void:
	print("New turn for ", slot.hero.hero_data.name)
	active_slot = slot
	var context = CombatContext.new(slot, [], self)
	await get_tree().process_frame
	
	# PHASE 1: PRE_TURN / TURN_START
	GameEvents.combat_event.emit(Enums.TriggerEvent.ON_TURN_START, context)
	await wait_for_stack_to_clear()
	if slot.hero == null: return
	
	# Status verification
	if not slot.hero.can_act():
		print(slot.hero.hero_data.name, " is incapacitated and skips their turn!")
		GameEvents.combat_event.emit(Enums.TriggerEvent.ON_TURN_END, context)
		await wait_for_stack_to_clear()
		return
		
	# PHASE 2: BEFORE_ACT
	await wait_for_stack_to_clear()
	if slot.hero == null: return
	
	# PHASE 3: EXECUTE / ACTION_EXECUTION
	GameEvents.combat_event.emit(Enums.TriggerEvent.ON_EXECUTE_ACTION, context)
	await wait_for_stack_to_clear()
	
	if slot.hero == null:
		return
	else:
		slot.hero.has_acted = true
		
	# PHASE 4: AFTER_ACT
	await wait_for_stack_to_clear()
	if slot.hero == null: return
	
	# PHASE 5: POST_TURN / TURN_END
	GameEvents.combat_event.emit(Enums.TriggerEvent.ON_TURN_END, context)
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
	
func get_enemy_slots(acting_faction: Enums.Faction) -> Array[HeroSlot]:
	var raw_slots = enemy_slots if acting_faction == Enums.Faction.PLAYER else player_slots
	return raw_slots.filter(func(slot): return slot != null and slot.hero != null and slot.hero.get_current_stat(Enums.StatType.HP) > 0)

func get_friendly_slots(acting_faction: Enums.Faction) -> Array[HeroSlot]:
	var raw_slots = player_slots if acting_faction == Enums.Faction.PLAYER else enemy_slots
	return raw_slots.filter(func(slot): return slot != null and slot.hero != null and slot.hero.get_current_stat(Enums.StatType.HP) > 0)

func reset_round():
	for slot in hero_to_slot_map.values():
		slot.hero.has_acted = false


func create_slots():
	load_party(PlayerData.player_party, combat_ui.player_party, player_slots, Enums.Faction.PLAYER)
	if RunManager.current_encounter == null:
		printerr("CombatManager: No active encounter found!")
		return
	load_party(RunManager.current_encounter.enemy_team, combat_ui.enemy_party, enemy_slots, Enums.Faction.OPPONENT)
	
func load_party(party_data: Array, ui_parent: Node, target_slots_array: Array[HeroSlot], faction_enum: Enums.Faction):
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
			spawn_and_assign_hero(data, slot, faction_enum)

func add_hero(slot : HeroSlot, hero : Hero):
	if slot.hero != null: 
		remove_hero(slot)
		
	slot.hero = hero
	hero.activate()
	
	slot.play_animation("idle")
	hero_to_slot_map[hero] = slot
	slot.update_info()

func remove_hero(slot: HeroSlot):
	if slot.hero == null:
		return
		
	# FIXED: Cleanly unparent the node from the slot right here.
	# This ensures that traveling heroes are free to be re-parented in the next battle!
	var old_hero = slot.hero
	old_hero.deactivate()
	hero_to_slot_map.erase(old_hero)
	slot.hero = null
	slot.update_info()
	
func spawn_and_assign_hero(hero_source: Variant, slot: HeroSlot, faction: Enums.Faction) -> void:
	var hero: Hero
	if hero_source is Hero:
		hero = hero_source as Hero
		hero.prepare_for_combat()
	elif hero_source is HeroData:
		hero = Hero.create(hero_source)
	else:
		return
	
	hero.faction = faction
	
	# We only lock their action out if they were summoned during a turn phase 
	# where the active acting slot has ALREADY finished executing its profile.
	if is_processing and active_slot != null and active_slot.hero != null and active_slot.hero.has_acted:
		hero.has_acted = true
	else:
		hero.has_acted = false
		
	add_hero(slot, hero)

func cleanup_all_slots() -> void:
	for slot in player_slots + enemy_slots:
		if is_instance_valid(slot) and slot.hero != null:
			slot.hero.deactivate()
			slot.hero = null
	hero_to_slot_map.clear()

func win_combat() -> void:
	await wait_for_input("ui_accept")
	cleanup_all_slots()
	get_tree().change_scene_to_file("res://Scripts/Overworld/OverworldManager.tscn")
	
func lose_combat():
	await wait_for_input("ui_accept")
	cleanup_all_slots()
	get_tree().change_scene_to_file("res://Scripts/Overworld/OverworldManager.tscn")


func restart_combat_with_new_enemies() -> void:
	if RunManager.current_encounter == null:
		printerr("CombatManager: Cannot restart because current_encounter is missing!")
		return
		
	print("CombatManager: Discarding match and regenerating board layout...")
	
	# 1. Capture the structural type of the battle before discarding it
	var active_battle_type = RunManager.current_encounter.encounter_type
	
	# 2. SIGNAL & REFERENCE CLEANUP: Disconnects signals for both players and enemies
	cleanup_all_slots()
				
	# 3. CLEAN REAP: Clear out live variables and state machines
	effect_stack.clear()
	is_processing = false
	combat_active = true 
	
	# 4. DESTROY VISUAL NODES: Free the old slot scenes safely.
	# Player heroes stay alive automatically because PlayerData.player_party still references them!
	for slot in player_slots:
		if is_instance_valid(slot):
			slot.queue_free()
	player_slots.clear()
	
	for slot in enemy_slots:
		if is_instance_valid(slot):
			slot.queue_free()
	enemy_slots.clear()
	
	# 5. GENERATE NEW ENCOUNTER
	RunManager.roll_next_encounter(active_battle_type)
	
	if RunManager.current_encounter == null:
		printerr("CombatManager: RunManager failed to roll a new encounter. Aborting reset.")
		return
	
	# 6. RE-INITIALIZE
	await get_tree().process_frame
	
	create_slots()
	update_UI()
	
	print("CombatManager: Fresh encounter [", RunManager.current_encounter.encounter_name, "] successfully deployed!")
