extends Node2D
class_name Hero

var hero_data : HeroData
var current_HP : int
var current_damage : int
var current_speed : int
var current_range : int

@export var team: Enums.Team = Enums.Team.FRIEND

var has_acted = false
var behaviors: Dictionary [String, Behavior]

func _ready() -> void:
	## When the Hero Class loads (i.e. begins to exist) we call the functions below
	initialize_data()

func initialize_data():
	## This loads the information from the base resource class HeroData (which we do NOT want to meddle with)
	## into the Hero class.
	add_behavior(hero_data.base_action)
	current_HP = hero_data.base_HP
	current_damage = hero_data.base_damage
	current_speed = hero_data.base_speed
	current_range = hero_data.base_range
	print("Hero Initialized: ", hero_data.name)
	print("Source Speed: ", hero_data.base_speed, " -> Result: ", current_speed)
	print("Source Damage: ", hero_data.base_damage, " -> Result: ", current_damage)
	print("Source HP: ", hero_data.base_HP, " -> Result: ", current_HP)
	print("Source Range: ", hero_data.base_range, " -> Result: ", current_range)

func take_damage(damage : int, source : Hero):
	#Here we call the on_take_damage event to check behaviors
	#We deal damage according to the calculated damage
	current_HP -= damage
	

func add_behavior(behavior: Behavior):
	## This is used when we add another behavior to the Hero. Such as when an item is added, when a buff
	## is received, when they unlock a new ability etc. etc.
	var new_behavior = behavior.duplicate() ## Creates a unique copy so we don't mess with the Resource itself
	## We check if the dictionary of active_behaviors does NOT already have the behavior (i.e. if the Hero 
	## already has crit for example, we don't want to add another instance of the same identical behavior.)
	if behaviors.has(new_behavior) == false:
		## If it's not already in the list, add it.
		new_behavior.owner_hero = self
		behaviors[new_behavior.name] = new_behavior
		return true
	else:
		##If it is already on the list, run error message
		##(This check might be more confusing than not. Perhaps not needed.)
		print("Behavior " + new_behavior.name + "already exists in the dict.")
		return false
		
func remove_behavior(behavior_name: String):
	## Check if the behavior exists in the dictionary
	if behaviors.has(behavior_name):
		## If it does, grab it
		var behavior_instance = behaviors.get(behavior_name)
		## Remove it from the dictionary
		behaviors.erase(behavior_name)

func trigger_behavior_event(event_name: String, data = null):
	print("Triggering ", event_name, " event.")
	for i in behaviors:
		if behaviors[i].has_method(event_name):
			behaviors[i].call(event_name, data)
			
## Use this for modifying values (e.g., calculating damage)
func apply_value_modifier(event_name: String, base_value) -> int:
	var modified_value = base_value
	for i in behaviors:
		if behaviors[i].has_method(event_name):
			## The 'call' method passes the current value and expects the modified value back
			modified_value = behaviors[i].call(event_name, modified_value)
	return modified_value
