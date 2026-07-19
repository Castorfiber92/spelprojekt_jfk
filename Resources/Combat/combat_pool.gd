extends Resource
class_name CombatPool
@export var area_id: int = 1
@export var normal_encounters: Array[CombatComposition] = []
@export var elite_encounters: Array[CombatComposition] = []
@export var boss_encounters: Array[CombatComposition] = []

func load_pool_data() -> void:
	var base_path = "res://Resources/Combat/Combat Compositions/Encounters_Area_" + str(area_id) + "/"
	
	normal_encounters = load_folder(base_path + "Normal_Encounters/")
	elite_encounters = load_folder(base_path + "Elite_Encounters/")
	boss_encounters = load_folder(base_path + "Boss_Encounters/")

func load_folder(path: String) -> Array[CombatComposition]:
	var list: Array[CombatComposition] = []
	if !DirAccess.dir_exists_absolute(path): return list
	
	var dir = DirAccess.open(path)
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		# Godot editor uses .tres, exported games use .remap/.tres
		if !dir.current_is_dir() and (file_name.ends_with(".tres") or file_name.ends_with(".remap")):
			var clean_name = file_name.replace(".remap", "")
			var res = load(path + clean_name) as CombatComposition
			if res:
				list.append(res)
		file_name = dir.get_next()
		
	return list
