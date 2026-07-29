extends Node

# This memory array will act as your lightning-fast database roster at runtime
var master_hero_roster: Array[HeroData] = []

func _ready() -> void:
	# Build the cache the absolute millisecond the game boots up
	_pre_index_all_heroes()

func _pre_index_all_heroes() -> void:
	master_hero_roster.clear()
	var base_path = "res://Resources/Heroes/"
	
	print("DatabaseManager: Indexing heroes folder on startup...")
	_crawl_and_index_recursive(base_path)
	print("DatabaseManager: Successfully cached ", master_hero_roster.size(), " heroes for runtime usage.")

func _crawl_and_index_recursive(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path): 
		return
	
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if dir.current_is_dir():
				if not file_name.begins_with("."): # Skip hidden system folders
					_crawl_and_index_recursive(path.path_join(file_name))
			else:
				# Support standard editor files (.tres) AND compiled export formats (.remap)
				if file_name.ends_with(".tres") or file_name.ends_with(".remap"):
					var clean_name = file_name.replace(".remap", "")
					# Load it dynamically first without an aggressive casting line
					var loaded_res = load(path.path_join(clean_name))

					# Safely check if it matches your custom resource type
					if loaded_res is HeroData:
						master_hero_roster.append(loaded_res)
			file_name = dir.get_next()
		dir.list_dir_end()

## Your new, instantaneous randomizer function
func get_random_hero_data(include_minions = false) -> HeroData:
	var available_heroes = master_hero_roster.filter(func(hero): return include_minions or not hero.is_minion)
	if not available_heroes.is_empty():
		return available_heroes.pick_random()
		
	printerr("DatabaseManager: Runtime hero cache array is completely empty!")
	return null
	
func get_all_heroes_by_tribe(target_tribe: Enums.Tribe, include_minions = false) -> Array[HeroData]:
	var matching_heroes: Array[HeroData] = []
	
	for hero in master_hero_roster:
		# Added include_minions filter pass to match your argument flag!
		if hero and hero.tribe == target_tribe:
			if include_minions or not hero.is_minion:
				matching_heroes.append(hero)
			
	return matching_heroes
