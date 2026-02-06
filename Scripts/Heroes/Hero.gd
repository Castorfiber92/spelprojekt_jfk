extends Node2D
class_name Hero

@export var hero : HeroData
@export var current_HP : float
@export var current_damage : float
var behaviors: Dictionary [String, BehaviorData]

func _ready() -> void:
	## When the Hero Class loads (i.e. begins to exist) we call the functions below
	initialize_data()
	
func initialize_data():
	## This loads the information from the base resource class HeroData (which we do NOT want to meddle with)
	## into the Hero class. 
	current_HP = hero.base_HP
	current_damage = hero.base_damage
	
func add_behavior(behavior: BehaviorData):
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
		##This check might be more confusing than not. Perhaps not needed.
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
