@tool
extends Node

@export_file("*.csv") var csv_path: String
@export_dir var output_dir: String = "res://Resources/Heroes/"

@export_tool_button("Generate Heroes","Callable") var generate_heroes_action = generate_heroes 

func generate_heroes():
	# If we are not currently inside the editor, i.e. the game is running, do nothing
	if not Engine.is_editor_hint():
		return
	
	if csv_path == "" or not FileAccess.file_exists(csv_path):
		printerr("Hero Importer: Invalid CSV path!")
		return
	
	# Pre-scan the filesystem to ensure Godot's cache is up to date
	EditorInterface.get_resource_filesystem().scan()
	
	# Open the CSV file
	var file = FileAccess.open(csv_path, FileAccess.READ)
	# Skip headers
	var _headers = file.get_csv_line() 
	
	# While we are not at the end of the file
	while not file.eof_reached():
		var row = file.get_csv_line()
		# Skip rows that are empty or do not have enough columns
		# - keep this updated accordingly to how many values we have in the CSV
		if row.size() < 9: 
			continue 
		
		# Declare which row is which data
		var h_name   = row[0].strip_edges()
		# Skip rows with no name
		if h_name == "": 
			continue 
		var h_description   = row[1].strip_edges()
		var tribe_string = row[2].strip_edges().to_lower()
		var h_tribe = Enums.Tribe_MAP.get(tribe_string, Enums.Tribe.CRITTER) # Default to Critter if not found
		var h_hp     = int(row[3])
		var h_dmg    = int(row[4])
		var h_spd    = int(row[5])
		var h_rng    = int(row[6])
		var act_name = row[7].strip_edges()
		var abl_list = row[8].strip_edges()
		
		# Build the subfolder path based on the tribe name
		# capitalize() turns "orc" into "Orc" for the folder name
		var tribe_folder_name = tribe_string.capitalize()
		var tribe_dir = output_dir.path_join(tribe_folder_name)
		
		# Ensure the specific tribe subfolder exists
		if not DirAccess.dir_exists_absolute(tribe_dir):
			DirAccess.make_dir_recursive_absolute(tribe_dir)
		
		# Define the path to the specific output directory and subfolder.
		var save_path = tribe_dir.path_join(h_name.validate_filename() + ".tres")

		# If the resource already exists, load it, otherwise create a new one
		var res: HeroData = load(save_path) if FileAccess.file_exists(save_path) else HeroData.new()
		
		# Update the resources accordingly, we use clamp to make sure the values do not overextend
		res.name = h_name
		res.description = h_description
		res.tribe = h_tribe
		res.base_HP = clampi(h_hp, 10, 50)
		res.base_damage = clampi(h_dmg, 1, 10)
		res.base_speed = clampi(h_spd, 1, 100)
		res.base_range = clampi(h_rng, 1, 5)
		
		# Find Base Action directly from an existing resource in Godot - Make sure this actually exists
		res.base_action = find_behavior_globally(act_name)
		
		# Find Array of Abilities, we clear it so we don't add multiple instances of same abilities
		# However, keep in mind this means that the array of abilities will always be overwrited
		# When we use this tool
		res.abilities.clear()
		# If the strings here are empty, there is simply no abilities
		if abl_list != "":
			# We separate the abilities by comma in the CSV
			for a_name in abl_list.split(","):
				# Find correect behaviors - Make sure they actually exists
				var behavior = find_behavior_globally(a_name.strip_edges())
				if behavior:
					# If we find the behavior, add it to the resource
					res.abilities.append(behavior)
		# Save the resource
		ResourceSaver.save(res, save_path)
		print("Successfully Synced: ", h_name)
			
	# Close the file
	file.close()
	print("--- Import Task Finished ---")
	
## Uses Godot's internal FileSystem cache to find resources by name instantly
func find_behavior_globally(behavior_name: String) -> Behavior:
	if behavior_name == "": return null
	
	var efs = EditorInterface.get_resource_filesystem()
	var root = efs.get_filesystem()
	var found_path = _find_file_in_cache(root, behavior_name + ".tres")
	
	if found_path != "":
		return load(found_path) as Behavior if found_path != "" else null 
	
	printerr("Could not find Behavior resource: ", behavior_name)
	return null

## Recursive search through Godot's cached EditorFileSystem (Fast)
func _find_file_in_cache(dir: EditorFileSystemDirectory, target_file: String) -> String:
	# Check files in current cached directory
	for i in dir.get_file_count():
		if dir.get_file(i).to_lower() == target_file.to_lower():
			return dir.get_file_path(i)
	
	# Check subdirectories
	for i in dir.get_subdir_count():
		var path = _find_file_in_cache(dir.get_subdir(i), target_file)
		if path != "": return path
		
	return ""
