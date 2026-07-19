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
					var res = load(path.path_join(clean_name)) as HeroData
					if res:
						master_hero_roster.append(res)
			file_name = dir.get_next()
		dir.list_dir_end()

## Your new, instantaneous randomizer function
func get_random_hero_data() -> HeroData:
	if not master_hero_roster.is_empty():
		return master_hero_roster.pick_random()
		
	printerr("DatabaseManager: Runtime hero cache array is completely empty!")
	return null
	
func get_all_heroes_by_tribe(target_tribe: Enums.Tribe) -> Array[HeroData]:
	var matching_heroes: Array[HeroData] = []
	
	for hero in master_hero_roster:
		if hero and hero.tribe == target_tribe:
			matching_heroes.append(hero)
			
	return matching_heroes
