extends Node2D
class_name Hero

var hero_data : HeroData
var current_tier : HeroData.HeroTier
var current_HP : int
var maximum_HP : int
var current_damage : int
#var current_spellpower : int
var current_speed : int
var current_range : int
var current_crit_chance : float
@export var team: Enums.Team = Enums.Team.FRIEND

var has_acted = false
var behaviors: Dictionary[String, Behavior] = {}

signal has_died
signal behavior_removed()

static func create(data: HeroData) -> Hero:
	var new_hero = Hero.new()
	new_hero.hero_data = data.duplicate(true) as HeroData
	new_hero.initialize_data()
	return new_hero

func initialize_data():
	## This loads the information from the base resource class HeroData (which we do NOT want to meddle with)
	## into the Hero class.
	# Add the basic action-behavior
	if hero_data.base_action:
		var base_action_instance = Behavior.create(hero_data.base_action)
		add_behavior(base_action_instance)
	# Add the basic abilities
	for ability_res in hero_data.abilities:
		var ability_instance = Behavior.create(ability_res)
		add_behavior(ability_instance)
	for behavior_name in behaviors:
		var b: Behavior = behaviors[behavior_name]
		b.owner_hero = self 
	reset_temporary_data()

func prepare_for_combat():
	reset_temporary_data()
	clear_temporary_buffs()

func reset_temporary_data():
	current_HP = hero_data.base_HP
	maximum_HP = current_HP
	current_damage = hero_data.base_damage
	current_speed = hero_data.base_speed
	current_range = hero_data.base_range
	current_crit_chance = hero_data.base_crit_chance
	has_acted = false
	#current_spellpower = hero_data.base_spellpower
	
func clear_temporary_buffs():
	var keys_to_remove: Array = []
	for behavior_name in behaviors:
		var behavior_instance = behaviors[behavior_name]
		# Check if the behavior instance has a type property and if it equals buff
		if "type" in behavior_instance.data and behavior_instance.data.type == BehaviorData.BehaviorType.BUFF:
			keys_to_remove.append(behavior_name)
	for behavior_name in keys_to_remove:
		behaviors.erase(behavior_name)
		
func take_damage(damage : int, source : HeroSlot) -> Dictionary:
	var old_hp = current_HP
	print (self.hero_data.name, " takes ", damage, " damage from ", source.hero.hero_data.name)
	# 1. Apply the damage math cleanly
	current_HP -= damage
	
	# 2. Return a pure, synchronous data snapshot back to the DamageEffect
	return {
		"damage": damage,
		"was_lethal": current_HP <= 0
	}
		
func heal_HP(value : int, source : HeroSlot) -> Dictionary:
	var old_hp = current_HP
	current_HP = clamp(current_HP + value, 0, maximum_HP)
	return {
		"value": value,
		"was_fullheal" : current_HP == maximum_HP
	}

func can_act() -> bool:
	# If any behavior in our dictionary blocks actions, the hero cannot act
	for behavior : Behavior in behaviors.values():
		if behavior.data.blocks_action:
			return false
	return true

func add_behavior(new_behavior: Behavior):
	## This is used when we add another behavior to the Hero. Such as when an item is added, when a buff
	## is received, when they unlock a new ability etc. etc.
	
	if new_behavior == null:
		return false
		
	var behavior_name = new_behavior.data.name
	
	## We check if the dictionary of active_behaviors does NOT already have the behavior (i.e. if the Hero 
	## already has crit for example, we don't want to add another instance of the same identical behavior.)
	if behaviors.has(behavior_name) == false:
		## If it's not already in the list, add it.
		new_behavior.owner_hero = self
		behaviors[behavior_name] = new_behavior
		return true
	else:
		print("Applying Behavior " + behavior_name)
		# If it exists, but is a buff
		var existing_behavior = behaviors[behavior_name]
		
		if existing_behavior.data.type == BehaviorData.BehaviorType.BUFF:
			if existing_behavior.data.base_stacks == 0 or new_behavior.data.base_stacks == 0:
				print("Permanent/Non-stacking behavior found: ", existing_behavior.data.name)
				return false
			# Check if the behavior only wants to add its stacks rather than replace them
			if existing_behavior.data.add_stacks == true:
				existing_behavior.current_stacks += new_behavior.current_stacks 
				print("Added stacks!")
				return true
			# Otherwise apply the largest strength of the buff
			existing_behavior.current_stacks = max(existing_behavior.current_stacks, new_behavior.current_stacks)
			print("Updated stacks!")
			return true
		print("Behavior " + new_behavior.data.name + "already exists in the dict.")
		return false
		
func remove_behavior(behavior_instance: Behavior):
	if behavior_instance == null or behavior_instance.data == null:
		return
	## Check if the behavior exists in the dictionary
	## we might want to change this so that it checks for the specific behavior instead of string
	var behavior_key: String = behavior_instance.data.name
	_deferred_remove.call_deferred(behavior_key)


func _deferred_remove(behavior_key: String):
	if behaviors.has(behavior_key):
		behaviors.erase(behavior_key)
		behavior_removed.emit() # Notify UI or game listeners cleanly

func get_behaviors():
	return behaviors.values()

func trigger_behavior_event(event_type : Enums.TriggerEvent, source_or_context: Variant, targets : Array[HeroSlot] = [], combat_manager : CombatManager = null):
	var event_name = Enums.TRIGGER_STRINGS.get(event_type, "")
	
	# Extract our manager reference safely from the incoming snapshot
	if source_or_context is CombatContext:
		combat_manager = source_or_context.manager
	
	if combat_manager == null:
		return

	# Locate this hero's unique board slot anchor to map spatial/range rules
	var local_hero_slot = combat_manager.hero_to_slot_map.get(self)
	if local_hero_slot == null:
		return

	# Iterate through active passive listeners
	for i in behaviors:
		var behavior_instance = behaviors[i]
		
		if behavior_instance.has_method(event_name):
			# 1. INDEPENDENT REACTION CONTEXT: Born completely blank and fresh!
			# This is what behavior_instance will use to target its spells.
			var reactive_context = CombatContext.new(local_hero_slot, [], combat_manager)
			
			# 2. AUTOMATION GATE: Because it is blank, this is guaranteed to execute, 
			# matching Siphon Soul's blueprint settings (FRIEND, ALL, etc.) natively!
			reactive_context.targets = reactive_context.resolve_targets(behavior_instance, combat_manager)
			
			# 3. THE TWO-ARGUMENT EMISSION: Pass the fresh targeting context AND the historical attack context data
			behavior_instance.call(event_name, reactive_context, source_or_context)

func get_stat(stat_type: Enums.StatType) -> int:
	# 1. Establish the baseline nude stats
	var calculated_stats = {
		Enums.StatType.SPEED: hero_data.base_speed,
		Enums.StatType.RANGE: hero_data.base_range,
		Enums.StatType.DAMAGE: hero_data.base_damage,
		Enums.StatType.MAX_HP: hero_data.base_HP,
		Enums.StatType.CRIT: hero_data.base_crit_chance
	}
	
	# 2. Automatically sweep behaviors for modifications
	for b in get_behaviors():
		# Direct data object reference (no method-string building required)
		var data_res = b.data
		if data_res.has_method("_execute_stat_modification"):
			data_res._execute_stat_modification(calculated_stats)
			
	# 3. Safely return the requested stat type
	return calculated_stats.get(stat_type, 0)
## Use this for modifying values (e.g., calculating damage)
func apply_value_modifier(event_name: String, base_value) -> int:
	var modified_value = base_value
	for i in behaviors:
		if behaviors[i].has_method(event_name):
			## The 'call' method passes the current value and expects the modified value back
			modified_value = behaviors[i].call(event_name, modified_value)
	return modified_value
