extends Control
class_name MainMenuManager

const TRIBE_ORDER: Array[Enums.Tribe] = [
	Enums.Tribe.CRITTER,
	Enums.Tribe.GNOME,
	Enums.Tribe.UNDEAD,
	Enums.Tribe.ORC
]

var menu_buttons: Array[Node] = [] 

func _ready() -> void:
	connect_ui_elements()

func connect_ui_elements() -> void:
	var raw_nodes: Array[Node] = find_children("*", "Button", true)
	menu_buttons.assign(raw_nodes)
	
	for i in range(menu_buttons.size()):
		var button = menu_buttons[i]
		# Ensure we don't look for a tribe index that doesn't exist in our array
		if button and i < TRIBE_ORDER.size():
			var assigned_tribe = TRIBE_ORDER[i]
			# Bind the actual Tribe enum directly to the click event!
			button.pressed.connect(on_button_pressed.bind(assigned_tribe))


func on_button_pressed(selected_tribe: Enums.Tribe) -> void:
	print("Loading party for tribe: ", Enums.Tribe.keys()[selected_tribe])
	load_random_party_by_tribe(selected_tribe)
	get_tree().change_scene_to_packed(Preloads.overworld_scene)
	
func load_random_party_by_tribe(target_tribe: Enums.Tribe) -> void:
	var path_to_heroes = "res://Resources/Heroes/" # Make sure capitalization matches your folder exactly
	var matching_heroes: Array[HeroData] = []
	
	# 1. Start the recursive scan from the root folder
	scan_directory_for_tribe(path_to_heroes, target_tribe, matching_heroes)

	if matching_heroes.is_empty():
		print("No heroes found for this tribe anywhere in the subfolders!")
		return

	# 2. Clear old test data and fill player_party with random matching heroes
	PlayerData.player_party.clear()
	
	var desired_party_size = 5
	for i in range(desired_party_size):
		var random_hero = matching_heroes.pick_random()
		var runtime_hero = Hero.create(random_hero)
		PlayerData.player_party.append(runtime_hero)
		
	print("Party updated! Current members: ", PlayerData.player_party.size())

func scan_directory_for_tribe(dir_path: String, target_tribe: Enums.Tribe, results_array: Array[HeroData]) -> void:
	var dir = DirAccess.open(dir_path)
	if not dir:
		return
		
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		# Ignore system shortcuts
		if file_name == "." or file_name == "..":
			file_name = dir.get_next()
			continue
			
		# If it's a subfolder (like Critters), dig into it recursively
		if dir.current_is_dir():
			var subfolder_path = dir_path.path_join(file_name) + "/"
			scan_directory_for_tribe(subfolder_path, target_tribe, results_array)
		else:
			# If it's a file, check if it's a hero resource
			if file_name.ends_with(".tres") or file_name.ends_with(".tres.remap"):
				var clean_name = file_name.replace(".remap", "")
				var clean_path = dir_path.path_join(clean_name)
				var hero_res = load(clean_path) as HeroData
				
				if hero_res and hero_res.tribe == target_tribe:
					results_array.append(hero_res)
					
		file_name = dir.get_next()
	dir.list_dir_end()
