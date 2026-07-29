extends Resource
class_name CombatPool
@export var area_id: int = 1
@export var normal_encounters: Array[CombatComposition] = []
@export var elite_encounters: Array[CombatComposition] = []
@export var boss_encounters: Array[CombatComposition] = []

func load_pool_data() -> void:
	var base_path = "res://Resources/Combat/Combat Compositions/Encounters_Area_" + str(area_id) + "/"
	
	# Clear existing data first if reloading
	normal_encounters.clear()
	elite_encounters.clear()
	boss_encounters.clear()
	
	# Pass the arrays directly into the function
	load_folder(base_path + "Normal_Encounters/", normal_encounters)
	load_folder(base_path + "Elite_Encounters/", elite_encounters)
	load_folder(base_path + "Boss_Encounters/", boss_encounters)

# Change the function to take a target array and return nothing (void)
func load_folder(path: String, target_array: Array) -> void:
	if !DirAccess.dir_exists_absolute(path): return
	
	# FIX: Explicitly tell Godot to treat this reference as an Array of CombatCompositions
	var typed_target := target_array as Array[CombatComposition]
	
	var dir = DirAccess.open(path)
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if !dir.current_is_dir() and (file_name.ends_with(".tres") or file_name.ends_with(".remap")):
			var clean_name = file_name.replace(".remap", "")
			
			# Clean up the load line to match our new standard
			var loaded_res = load(path + clean_name)
			if loaded_res is CombatComposition:
				# Append directly to our safely cast local array
				typed_target.append(loaded_res)
				
		file_name = dir.get_next()
