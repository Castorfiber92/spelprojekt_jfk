extends Control
class_name MainMenuManager

var TRIBE_ORDER: Array[Enums.Tribe] = [
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
		if button and i < TRIBE_ORDER.size():
			var assigned_tribe = TRIBE_ORDER[i]
			button.pressed.connect(on_button_pressed.bind(assigned_tribe))

func on_button_pressed(selected_tribe: Enums.Tribe) -> void:
	print("Loading party for tribe: ", Enums.Tribe.keys()[selected_tribe])
	PlayerData.active_tribe = selected_tribe
	load_random_party_by_tribe(selected_tribe)
	get_tree().change_scene_to_packed(Preloads.overworld_scene)
	
func load_random_party_by_tribe(target_tribe: Enums.Tribe) -> void:
	# 1. Instantly pull the filtered array from the global database cache
	var matching_heroes: Array[HeroData] = DatabaseManager.get_all_heroes_by_tribe(target_tribe)

	if matching_heroes.is_empty():
		printerr("MainMenu: No cached heroes found for tribe: ", Enums.Tribe.keys()[target_tribe])
		return

	# 2. Clear old data and populate player_party with random matching heroes
	PlayerData.player_party.clear()
	
	var desired_party_size = 5
	for i in range(desired_party_size):
		var random_hero = matching_heroes.pick_random()
		var runtime_hero = Hero.create(random_hero)
		PlayerData.player_party.append(runtime_hero)
		
	print("Party updated! Current members: ", PlayerData.player_party.size())
