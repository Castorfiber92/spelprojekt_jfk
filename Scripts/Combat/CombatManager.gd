extends Node
class_name CombatManager

@export var combat_ui : CombatUI
##hero is the key, slot is the value
var hero_to_slot_map : Dictionary = {}
var player_slots : Array[HeroSlot]
var enemy_slots : Array[HeroSlot]
@export var active_slot : HeroSlot

##Below is temporary, for testing
@export var player_heroes : Array[HeroData]
@export var enemy_heroes : Array[HeroData]

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
	run_combat_loop()

func run_combat_loop():
	while combat_active:
		var next_hero_slot = get_next_acting_hero()
		
		# If no heroes can act, the round is over!
		if next_hero_slot == null:
			print("Press SPACE to start the round...")
			await wait_for_input("ui_accept")
			print("Next round started!")
			reset_round()
			await wait_for_stack_to_clear()
			continue # Restart the loop for the new round
			
		active_slot = next_hero_slot
		active_slot.highlight_slot()
		print("Next to act: ", active_slot.hero.hero_data.name)
		
		# Linear execution: Code completely pauses here until the turn and all cascades finish
		await execute_turn(active_slot)
		
		# --- ADDED FOR TESTING: PACING DELAY BETWEEN ACTIONS ---
		# Adjust the '0.5' to make the pause longer (e.g., 1.0) or shorter (e.g., 0.2)
		await get_tree().create_timer(0.2).timeout
		# -------------------------------------------------------
		
		# Clean up this specific turn completely before going to the top of the while-loop
		_wrap_up_turn(active_slot.hero)
		update_UI()

func wait_for_input(action_name: String):
	# This loop 'pauses' the logic without freezing the game engine
	while true:
		# Wait for exactly one frame to pass
		await get_tree().process_frame
		
		# Check if the specific action (Space/Enter) was just pressed
		if Input.is_action_just_pressed(action_name):
			return # This 'resolves' the await in the calling function

func get_next_acting_hero() -> HeroSlot:
	var candidates : Array[HeroSlot] = []
	for slot in hero_to_slot_map.values():
		if slot.hero and not slot.hero.has_acted:
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
	if not is_processing:
		process_stack()

func process_stack():
	is_processing = true
	
	while not effect_stack.is_empty():
		var effect = effect_stack.pop_front()
		
		# Safety fallback check
		if not hero_to_slot_map.has(effect.target): 
			continue
			
		# 1. Pipeline (Modifiers are calculated first)
		process_effect(effect)
		
		# 2. Polymorphic Execution & Visual Sequence Execution
		await effect.present(self)  # Orchestrated graphics presentation sequences
		effect.execute(self)       # Structural health changes
		
		update_UI()

	is_processing = false

	is_processing = false

func execute_turn(slot: HeroSlot):
	print("New turn")
	# PHASE: PRE_TURN
	current_phase = Enums.CombatPhase.PRE_TURN
	slot.hero.trigger_behavior_event("on_turn_start", slot) 
	await wait_for_stack_to_clear()
	# Check if the hero is available to act (not stunned/asleep/etc)
	if not slot.hero.can_act():
		print(slot.hero.hero_data.name, " is incapacitated and skips their turn!")
		perform_action(slot)
		await wait_for_stack_to_clear()
		slot.hero.trigger_behavior_event("on_turn_end", slot)
		await wait_for_stack_to_clear()
		return
	# PHASE: SELECT_ACTION
	current_phase = Enums.CombatPhase.SELECT_ACTION
	var action = slot.hero.hero_data.base_action 
	# PHASE: FIND_TARGETS
	current_phase = Enums.CombatPhase.FIND_TARGETS
	var targets = get_valid_targets(slot, action)
	
	if targets.is_empty():
		# What happens if it has no valid targets
		print(slot.hero.hero_data.name, " has no valid targets and skips their turn!")
		# DELETED: _wrap_up_turn(slot.hero) from here
		slot.hero.trigger_behavior_event("on_turn_end", slot)
		await wait_for_stack_to_clear()
		return
	# PHASE: BEFORE_ACT
	current_phase = Enums.CombatPhase.BEFORE_ACT
	slot.hero.trigger_behavior_event("on_before_act", slot)
	await wait_for_stack_to_clear()
	# PHASE: EXECUTE
	current_phase = Enums.CombatPhase.EXECUTE
	print(slot.hero.hero_data.name, " will be using ", action.name, " on ", ", ".join(targets.map(func(t): return t.hero.hero_data.name)))

	perform_action(slot, targets) # This handles the 'on_execute_action'
	await wait_for_stack_to_clear()
	# PHASE: AFTER_ACT
	current_phase = Enums.CombatPhase.AFTER_ACT
	slot.hero.trigger_behavior_event("on_after_act", slot)
	await wait_for_stack_to_clear()
	slot.hero.trigger_behavior_event("on_turn_end", slot)
	await wait_for_stack_to_clear()

func wait_for_stack_to_clear():
	while is_processing or not effect_stack.is_empty():
		await get_tree().process_frame

func _wrap_up_turn(hero: Hero):
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
	for b in effect.source.get_behaviors():
		if b.has_method("modify_outgoing_effect"):
			b.modify_outgoing_effect(effect)
	
	# 2. We check the target's behaviors and modify the incoming effect
	# (Armor, Shields, Damage Reduction, etc.)
	for b in effect.target.get_behaviors():
		if b.has_method("modify_incoming_effect"):
			b.modify_incoming_effect(effect)


func perform_action(source : HeroSlot, targets: Array[HeroSlot] = []):
	if source.hero.can_act():
		# We trigger the actual behavior event on the corresponding target
		source.hero.trigger_behavior_event("on_execute_action", source, targets)

	source.hero.has_acted = true
	
func clear_highlights():
	for i in player_slots:
		i.cleanup()
	for i in enemy_slots:
		i.cleanup()
		
func get_valid_targets(source: HeroSlot, action: Behavior) -> Array[HeroSlot]:
	var candidates: Array[HeroSlot] = []
	# Determine which team array to look at by the definition in a behavior
	match action.target_team:
		Enums.Team.SELF:
			return [source]
		Enums.Team.ENEMY:
			candidates = get_enemy_slots(source.hero)
		Enums.Team.FRIEND:
			candidates = get_friendly_slots(source.hero)
	# Delegate the actual filtering to the behavior script
	return action.get_valid_targets(source, candidates)
	
func get_enemy_slots(source: Hero) -> Array[HeroSlot]:
	# If the source is a Player, their enemies are in the enemy_slots
	if source.team == Enums.Team.FRIEND:
		return enemy_slots
	else:
		return player_slots

func get_friendly_slots(source: Hero) -> Array[HeroSlot]:
	# If the source is a Player, their friends are in the player_slots
	if source.team == Enums.Team.FRIEND:
		return player_slots
	else:
		return enemy_slots


func reset_round():
	for slot in hero_to_slot_map.values():
		slot.hero.has_acted = false
		slot.hero.trigger_behavior_event("on_round_start", slot)

func create_slots():
	##Here we will create slots according to the playerparty (which does not exist right now)
	## and according to what type of enemies we want to generate. Right now this is temporary,
	## so that we might begin just testing it. The generating/loading we will cover later on.
	load_player_party()
	load_enemy_party()
	
func set_hero(slot : HeroSlot, hero : Hero):
	##Assign the corresponding hero to the slot
	slot.hero = hero
	slot.play_animation("idle")
	##Map the slot/hero combination to the dictionary
	hero_to_slot_map[hero] = slot
	##Update the ui of the slot
	slot.update_info()
	hero.has_died.connect(remove_hero.bind(slot))

func load_player_party():
	for i in range(player_heroes.size()):
		var slot : HeroSlot = Preloads.hero_slot.instantiate()
		slot.index = i 
		##Add it to the UI
		combat_ui.player_party.add_child(slot)
		##Create a Hero class from the HeroData (so we don't mess up the Resource)
		var hero = Hero.new()
		##Set the Hero data according to the HeroData in the array above
		hero.hero_data = player_heroes[i].duplicate(true) 
		hero.initialize_data()
		##Assign the team to Player Array
		player_slots.append(slot)
		hero.team = Enums.Team.FRIEND
		##Update the slot with the correct hero
		set_hero(slot, hero)
		
func load_enemy_party():
	for i in enemy_heroes:
		var slot : HeroSlot = Preloads.hero_slot.instantiate()
		##Add it to the UI
		combat_ui.enemy_party.add_child(slot)
		##Create a Hero class from the HeroData (so we don't mess up the Resource)
		var hero = Hero.new()
		##Set the Hero data according to the HeroData in the array above
		hero.hero_data = i
		hero.initialize_data()
		##Assign the team to Enemy Array
		enemy_slots.append(slot)
		hero.team = Enums.Team.ENEMY
		##Update the slot with the correct hero
		set_hero(slot, hero)

func remove_hero(slot : HeroSlot):
	slot.hero.has_died.disconnect(remove_hero.bind(slot))
	hero_to_slot_map.erase(slot.hero)
	slot.hero = null
	slot.update_info()
	

func win_combat():
	print("You win the battle!")
	
func lose_combat():
	print("You lose the battle!")
func initialize_combat():
	pass
	
