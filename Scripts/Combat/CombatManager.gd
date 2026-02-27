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

func _ready() -> void:
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

func execute_turn(hero: Hero):
	# We grab the base action, that might be a heal, an attack etc.
	var base_action = hero.hero_data.base_action
	# We find a proper target(s) for the action
	# We might need additional checks here for single target/multi target etc
	var targets = get_valid_targets(hero, base_action)
	# After finding a target, we perform the action
	perform_action(hero, targets)

func perform_action(source : Hero, targets: Array[Hero]):
	# We trigger the actual behavior event on the corresponding target
	print("performing action...")
	source.trigger_behavior_event("on_execute_action", targets)
	# We update that the hero has made their action
	source.has_acted = true
	# We start the next turn
	clear_highlights()
	start_next_turn()
	
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
	var action_range = source.apply_value_modifier("on_calculate_range", r)

	# Filter by Range
	var reachables: Array[Hero] = []
	for i in candidates.size():
		if candidates[i].hero != null and (i + 1) <= action_range:
			reachables.append(candidates[i].hero)
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
	slot.hero = null
	
func initialize_combat():
	pass
	
