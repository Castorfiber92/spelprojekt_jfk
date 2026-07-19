extends Node

# We should track the active roster here as well in the future, so we can grab random heroes from
# that inside shops, encounters etc.

# Tracks game state across scenes
var current_area_id: int = 1
var active_pool: CombatPool
var current_encounter: CombatComposition

func _ready() -> void:
	# Instantiate a fresh instance of your pool when the game boots up
	initialize_area_pool(current_area_id)

func initialize_area_pool(area_index: int) -> void:
	current_area_id = area_index
	
	# Create the resource dynamically, assign the ID, and load the folders
	active_pool = CombatPool.new()
	active_pool.area_id = current_area_id
	active_pool.load_pool_data()

## Call this from your map scene before changing to the combat scene
func roll_next_encounter(type: CombatComposition.CombatType) -> void:
	if not active_pool:
		printerr("RunManager: No active combat pool loaded!")
		return
		
	# Select a random fight out of your clean CombatPool arrays
	var roll_pool: Array[CombatComposition] = []
	match type:
		CombatComposition.CombatType.ELITE:
			roll_pool = active_pool.elite_encounters
		CombatComposition.CombatType.BOSS:
			roll_pool = active_pool.boss_encounters
		_:
			roll_pool = active_pool.normal_encounters
			
	if not roll_pool.is_empty():
		current_encounter = roll_pool.pick_random()
		print("RunManager: Successfully rolled battle -> ", current_encounter.encounter_name)
	else:
		printerr("RunManager: No encounters available for Type: ", type)
		current_encounter = null
