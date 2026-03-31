extends Node
class_name CombatManager

@export var combat_ui : CombatUI
##hero is the key, slot is the value
var hero_to_slot_map : Dictionary = {}
var player_slots : Array[HeroSlot]
var enemy_slots : Array[HeroSlot]
@export var active_hero : Hero

##Below is temporary, for testing
@export var player_heroes : Array[HeroData]
@export var enemy_heroes : Array[HeroData]

##Preloading the packed scene, this should not be here later. Create a preload script with
##constant paths that we can check
@onready var hero_slot: = preload("res://Scenes/HeroSlot.tscn")

## Stack variables
var effect_stack: Array[CombatEffect] = []
var is_processing: bool = false

var current_phase : Enums.CombatPhase : set = update_phase_UI

func update_phase_UI(new_value: Enums.CombatPhase) -> void:
	var string = Enums.CombatPhase.keys()[current_phase]
	combat_ui.phase_ui.text = string
	current_phase = new_value

func _ready() -> void:
	GameEvents.effect_created.connect(_on_effect_requested)
	create_slots()
	start_next_turn()

# The Helper Function
func wait_for_input(action_name: String):
	# This loop 'pauses' the logic without freezing the game engine
	while true:
		# Wait for exactly one frame to pass
		await get_tree().process_frame
		
		# Check if the specific action (Space/Enter) was just pressed
		if Input.is_action_just_pressed(action_name):
			return # This 'resolves' the await in the calling function

func start_next_turn():
	active_hero = null
	## Get all active heroes from the dictionary that has not yet moved
	var candidates : Array[Hero]
	for hero : Hero in hero_to_slot_map.keys():
		if not hero.has_acted:
			candidates.append(hero)
	
	if candidates.is_empty():
		print("Press SPACE to start the round...")
		await wait_for_input("ui_accept")
		print("Next round started!")
		reset_round()
		return
	## Sort the heroes based on their speed
	## Higher speed moves first
	candidates.sort_custom(func(a, b): return a.current_speed > b.current_speed)
	## The first hero in the sorted list is the winner
	active_hero = candidates[0]
	# This is not final, only simple for testing, to show the active hero
	var slot : HeroSlot = hero_to_slot_map[active_hero]
	slot.highlight_slot()
	print("Next to act: ", active_hero.hero_data.name)
	await wait_for_input("ui_accept")
	# Trigger the turn flow
	execute_turn(active_hero)
	# Update the visuals
	update_UI()
	
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
		var slot : HeroSlot = hero_to_slot_map[effect.target]
		# 1. Pipeline (Modifiers)
		process_effect(effect)
		match effect.type:
			"DAMAGE":
				# 2. Execution (Actually change HP)
				effect.target.take_damage(effect.value, effect.source)
				await slot.apply_damage_effect()
			"HEAL":
				pass # For now (not applicable yet)
			"SHIELD":
				pass # For now (not applicable yet)

		# Add a small 'await' somehow for animations/delays
		# await get_tree().create_timer(0.1).timeout

	is_processing = false

func execute_turn(hero: Hero):
	print("New turn")
	# PHASE: PRE_TURN
	current_phase = Enums.CombatPhase.PRE_TURN
	hero.trigger_behavior_event("on_turn_start") 
	# PHASE: SELECT_ACTION
	current_phase = Enums.CombatPhase.SELECT_ACTION
	var action = hero.hero_data.base_action 
	# PHASE: FIND_TARGETS
	current_phase = Enums.CombatPhase.FIND_TARGETS
	var targets = get_valid_targets(hero, action)
	
	if targets.is_empty():
		# Edit  what happens if it has no valid targets
		print(hero.hero_data.name, " has no valid targets and skips!")
		_wrap_up_turn(hero)
		return
	# PHASE: BEFORE_ACT
	current_phase = Enums.CombatPhase.BEFORE_ACT
	hero.trigger_behavior_event("on_before_act", targets)
	# PHASE: EXECUTE
	current_phase = Enums.CombatPhase.EXECUTE
	print(hero.hero_data.name, " will be using ", action.name)
	perform_action(hero, targets) # This handles the 'on_execute_action'
	# PHASE: AFTER_ACT
	current_phase = Enums.CombatPhase.AFTER_ACT
	await wait_for_input("ui_accept")
	hero.trigger_behavior_event("on_after_act", targets)
	_wrap_up_turn(hero)

func _wrap_up_turn(hero: Hero):
	hero.has_acted = true
	current_phase = Enums.CombatPhase.IDLE
	clear_highlights()
	update_UI()
	start_next_turn()

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

# This is to check whether there are stats indepent from specific behaviors. Such as flat increases
func get_modified_stat(hero: Hero, stat_name: String, base_value: int) -> int:
	var modified_value = base_value
	var hook_name = "modify_" + stat_name # e.g., "modify_range"
	
	for b in hero.get_behaviors():
		if b.has_method(hook_name):
			modified_value = b.call(hook_name, modified_value)
			
	return modified_value

func perform_action(source : Hero, targets: Array[Hero]):
	# We trigger the actual behavior event on the corresponding target
	source.trigger_behavior_event("on_execute_action", targets)

	source.has_acted = true
	
func clear_highlights():
	for i in player_slots:
		i.cleanup()
	for i in enemy_slots:
		i.cleanup()

func get_valid_targets(source: Hero, action: Behavior) -> Array[Hero]:
	var candidates: Array[HeroSlot] = []
	
	# Determine which team array to look at by the definition in a behavior
	match action.target_team:
		Enums.Team.ENEMY:
			candidates = get_enemy_slots(source)
		Enums.Team.FRIEND:
			candidates = get_friendly_slots(source)
		Enums.Team.SELF:
			return [source]

	# Determine the range to use, if the range of the action is set to 0 we use the range of the hero
	var r = action.range if action.range > 0 else source.current_range
	# Then we check all behaviors if there are any that modifies stats, in this case range.
	var action_range = get_modified_stat(source, "range", r)

	# Filter by Range
	var reachables: Array[Hero] = []
	var current_distance = 0
	for slot in candidates:
		if slot.hero != null:
			current_distance += 1 # this means we found a target
			if current_distance <= action_range: # if the target is within range
				reachables.append(slot.hero)
	##Check if the action is a target action, in that case return a random target
	if action.target_type == Enums.Target.SINGLE:
		if not reachables.is_empty():
			var target = reachables.pick_random()
			reachables.clear()
			reachables.append(target) 

	return reachables
	
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
	##Update the boolean status
	for hero : Hero in hero_to_slot_map.keys():
		hero.has_acted = false
		#Check for round start behavior
		hero.trigger_behavior_event("on_round_start")
	
	start_next_turn()

func create_slots():
	##Here we will create slots according to the playerparty (which does not exist right now)
	## and according to what type of enemies we want to generate. Right now this is temporary,
	## so that we might begin just testing it. The generating/loading we will cover later on.
	load_player_party()
	load_enemy_party()
	
func set_hero(slot : HeroSlot, hero : Hero):
	##Assign the corresponding hero to the slot
	slot.hero = hero
	##Map the slot/hero combination to the dictionary
	hero_to_slot_map[hero] = slot
	##Update the ui of the slot
	slot.update_info()
	hero.has_died.connect(remove_hero.bind(slot))

func load_player_party():
	for i in player_heroes:
		var slot : HeroSlot = hero_slot.instantiate()
		##Add it to the UI
		combat_ui.player_party.add_child(slot)
		##Create a Hero class from the HeroData (so we don't mess up the Resource)
		var hero = Hero.new()
		##Set the Hero data according to the HeroData in the array above
		hero.hero_data = i
		hero.initialize_data()
		##Assign the team to Player Array
		player_slots.append(slot)
		hero.team = Enums.Team.FRIEND
		##Update the slot with the correct hero
		set_hero(slot, hero)
		
func load_enemy_party():
	for i in enemy_heroes:
		var slot : HeroSlot = hero_slot.instantiate()
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

	
func initialize_combat():
	pass
	
