@tool
extends Node

@export_group("Generate Functions")
@export_tool_button("Sync CSV from Drive", "Callable") var sync_drive_action = download_csv_from_drive
@export_tool_button("Generate Heroes", "Callable") var generate_heroes_action = generate_heroes 
@export_tool_button("Generate Compositions", "Callable") var generate_compositions_action = run_composition_generation_loop

@export_group("Google Drive Sync")
## --- HEROES --- ##
@export var google_sheet_heroes_id: String = "17J7sFikfk8IrrhA2Krcp29_qytfdY_f5aiZjjxtkmh4"
@export_file("*.csv") var csv_path: String
@export_dir var output_dir: String = "res://Resources/Heroes/"
@export var google_sheet_gid: String = "0"

## --- ENCOUNTERS --- ##
@export var google_sheet_encounters_id: String = "1-U_LSzEQR9fS4nsDWHDSip6ZBVMgPtCO8XRdEJCEIO0"
## Just add your browser tab GIDs here in order!
## Click "Add Element": Index 0 is Area 1, Index 1 is Area 2, etc.
## Example: ["148302945", "882041763"]
@export var encounter_tab_gids: Array[String] = [
	"0",           # Area 1 GID
	"1305347074"  # Area 2 GID
	#"OUR_AREA_3_GID_HERE" # New pages here
]
## Target folder where combat encounter resources will be compiled and sorted
@export_dir var compositions_output_dir: String = "res://Resources/Combat/Combat Compositions/"

@export_group("Developer Utilities")
@export_tool_button("Export Valid Behaviors List", "Callable") var export_behaviors_action = export_valid_behaviors_list

# Caches and internal properties
var compositions_csv_path: String = "" 
var behavior_cache: Dictionary = {}
var sprite_cache: Dictionary = {}   
var hero_asset_cache: Dictionary = {}
var all_files: Array[String] = []

func export_valid_behaviors_list():
	if not Engine.is_editor_hint(): return
	
	print("Hero Importer: Scanning files for behavior filenames...")
	var all_files: Array[String] = []
	_get_all_files_on_disk("res://", all_files)
	
	var valid_filenames: Array[String] = []
	
	# --- Define filenames you want to ignore ---
	var ignored_behaviors = ["attack_basic", "heal_basic", "cast_basic", "attack_multi"]
	
	# Scan all files to find actual Behavior resources
	for path in all_files:
		if path.ends_with(".tres"):
			var loaded_res = load(path)
			
			# Ensure it is a behavior script before tracking its filename
			if loaded_res is Behavior:
				# Get the exact filename without the path
				var file_name_with_ext = path.get_file()
				# Remove the ".tres" extension to get the raw string
				var raw_filename = file_name_with_ext.replace(".tres", "").strip_edges()
				
				# --- Skip the filename if it matches our ignore list ---
				if raw_filename in ignored_behaviors:
					continue
				
				# Skip any filenames beginning with status, since these are the buffs being applied,
				# not the actual abilities
				if raw_filename.begins_with("status_"):
					continue
					
				if raw_filename != "" and not valid_filenames.has(raw_filename):
					valid_filenames.append(raw_filename)
					
	valid_filenames.sort() # Sort alphabetically for easy spreadsheet management
	
	# Save this out as a plain text file in your project directory
	var output_path = "res://valid_behaviors_list.txt"
	var file = FileAccess.open(output_path, FileAccess.WRITE)
	
	if file:
		for f_name in valid_filenames:
			file.store_line(f_name)
		file.close()
		print("--- Exported %d valid behavior filenames to %s ---" % [valid_filenames.size(), output_path])
	else:
		printerr("Failed to write behavior list file.")
		
func generate_heroes():
	# If we are not currently inside the editor, i.e. the game is running, do nothing
	if not Engine.is_editor_hint():
		return
	
	if csv_path == "" or not FileAccess.file_exists(csv_path):
		printerr("Hero Importer: Invalid CSV path!")
		return
	
	# Pre-scan the filesystem to ensure Godot's cache is up to date
	var efs = EditorInterface.get_resource_filesystem()
	efs.scan()
	
	# --- OPTIMIZATION: Index the disk file system EXACTLY ONCE ---
	print("Hero Importer: Building resource lookup index...")
	behavior_cache.clear()
	sprite_cache.clear()
	
	var all_files: Array[String] = []
	_get_all_files_on_disk("res://", all_files)
	
	for path in all_files:
		if path.ends_with(".tres"):
			var file_lower = path.get_file().strip_edges().to_lower()
			if file_lower.ends_with("_sprites.tres"):
				sprite_cache[file_lower] = path
			else:
				behavior_cache[file_lower] = path
	# ------------------------------------------------------------------
	
	# Open the CSV file
	var file = FileAccess.open(csv_path, FileAccess.READ)
	# Skip headers
	var _headers = file.get_csv_line() 
	
	# While we are not at the end of the file
	while not file.eof_reached():
		var row = file.get_csv_line()
		# Skip rows that are empty or do not have enough columns
		# - keep this updated accordingly to how many values we have in the CSV
		if row.size() < 10: 
			continue 
		
		# Declare which row is which data
		var h_name   = row[0].strip_edges()
		# Skip rows with no name
		if h_name == "": 
			continue 
		# Extra guard if the row has no hp/dmg e.g. it is not a hero, skip it.
		if row[4].strip_edges() == "" or row[5].strip_edges() == "":
			continue
		var h_description   = row[1].strip_edges()
		var tribe_string = row[2].strip_edges().to_lower()
		var h_tribe = Enums.Tribe_MAP.get(tribe_string, Enums.Tribe.CRITTER) # Default to Critter if not found
		var h_legendary = row[3].strip_edges().to_lower() == "true"
		
		var h_hp     = int(row[4])
		var h_dmg    = int(row[5])
		var h_spd    = int(row[6])
		var h_rng    = int(row[7])
		var act_name = row[8].strip_edges()
		var abl_list = row[9].strip_edges()
		
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
		res.is_legendary_eligible = h_legendary
		res.current_tier = HeroData.HeroTier.BRONZE
		res.base_HP = clampi(h_hp, 10, 50)
		res.base_damage = clampi(h_dmg, 1, 10)
		res.base_speed = clampi(h_spd, 1, 100)
		res.base_range = clampi(h_rng, 1, 5)
		
		# --- FUNCTIONAL CHANGE: Find Base Action directly from optimized cache ---
		res.base_action = find_behavior_globally(act_name)
		
		# Find Array of Abilities, we clear it so we don't add multiple instances of same abilities
		# However, keep in mind this means that the array of abilities will always be overwrited
		# When we use this tool
		var fresh_abilities: Array[Behavior] = [] # Hard-force a brand new mutable memory allocation
		
		# If the strings here are empty, there is simply no abilities
		if abl_list != "":
			# We separate the abilities by comma in the CSV
			for a_name in abl_list.split(","):
				# --- FUNCTIONAL CHANGE: Find correct behaviors via optimized cache ---
				var behavior = find_behavior_globally(a_name.strip_edges())
				if behavior:
					# If we find the behavior, add it to the resource
					fresh_abilities.append(behavior)
					
		res.abilities = fresh_abilities # Assign the completely independent array to the resource
					
		# --- FUNCTIONAL CHANGE: Check if matching sprite file exists using optimized cache ---
		var sprite_filename: String = h_name.to_lower().replace(" ", "_") + "_sprites.tres"
		if sprite_cache.has(sprite_filename):
			res.sprites = load(sprite_cache[sprite_filename]) as SpriteFrames
		else:
			printerr("Sprite for ", h_name, " not found or mismatched string.")
		# Save the resource
		ResourceSaver.save(res, save_path)
		print("Successfully Synced: ", h_name)
			
	# Close the file
	file.close()
	print("--- Import Task Finished ---")

func generate_compositions():
	if not Engine.is_editor_hint():
		return
	
	if compositions_csv_path == "" or not FileAccess.file_exists(compositions_csv_path):
		printerr("Composition Importer: Invalid CSV path!")
		return
		
	# --- 1. PRE-READ TARGETED CLEANUP ARCHITECTURE ---
	var valid_encounter_filenames: Array[String] = []
	var pre_read_file = FileAccess.open(compositions_csv_path, FileAccess.READ)
	var _discard_headers = pre_read_file.get_csv_line()
	
	while not pre_read_file.eof_reached():
		var row = pre_read_file.get_csv_line()
		if row.size() < 7: continue
		var name_check = row[0].strip_edges()
		if name_check != "":
			valid_encounter_filenames.append(name_check.validate_filename() + ".tres")
	pre_read_file.close()

	# --- 2. FILE SYSTEM SCAN & CACHE SYNCHRONIZATION ---
	var efs = EditorInterface.get_resource_filesystem()
	efs.scan()
	while efs.is_scanning():
		await Engine.get_main_loop().process_frame
	
	hero_asset_cache.clear()
	var local_files: Array[String] = []
	_get_all_files_on_disk("res://", local_files)
	for path in local_files:
		if path.ends_with(".tres"):
			var file_name_lower = path.get_file().strip_edges().to_lower()
			hero_asset_cache[file_name_lower] = path

	# FIXED: Stripping the space-dash sequence cleanly so paths are perfectly formatted
	var csv_filename = compositions_csv_path.get_file().get_basename()
	var formatted_area_folder = csv_filename.replace(" - ", "_").replace(" ", "_")
	
	# --- 3. EXECUTE SMART PURGE OF ORPHANED ENCOUNTERS ONLY ---
	var sub_folders = ["Normal_Encounters", "Elite_Encounters", "Boss_Encounters"]
	for sub in sub_folders:
		var check_folder = compositions_output_dir.path_join(formatted_area_folder).path_join(sub)
		if DirAccess.dir_exists_absolute(check_folder):
			var dir = DirAccess.open(check_folder)
			dir.list_dir_begin()
			var file_name = dir.get_next()
			while file_name != "":
				if file_name.ends_with(".tres") and not valid_encounter_filenames.has(file_name):
					print("Composition Importer: Removing obsolete stale encounter -> ", file_name)
					DirAccess.remove_absolute(check_folder.path_join(file_name))
					var import_track = check_folder.path_join(file_name + ".import")
					if FileAccess.file_exists(import_track):
						DirAccess.remove_absolute(import_track)
				file_name = dir.get_next()
			dir.list_dir_end()

	# --- 4. FLUSH PURGES FROM MEMORY BEFORE RECREATION ---
	var efs_purge = EditorInterface.get_resource_filesystem()
	efs_purge.scan()
	while efs_purge.is_scanning():
		await Engine.get_main_loop().process_frame

	# --- 5. EXECUTE GENERATION PARSER LOOP AND RESOURCE CREATION ---
	var file = FileAccess.open(compositions_csv_path, FileAccess.READ)
	var _headers = file.get_csv_line() 
	
	while not file.eof_reached():
		var row = file.get_csv_line()
		if row.size() < 7: continue 
		
		# Direct index extraction with no extra string checks
		var c_name = row[0]
		if c_name == "": continue
		
		var c_type = row[1]
		
		var sub_folder_name = "Normal_Encounters"
		if c_type == "ELITE": 
			sub_folder_name = "Elite_Encounters"
		elif c_type == "BOSS": 
			sub_folder_name = "Boss_Encounters"
			
		var sub_dir = compositions_output_dir.path_join(formatted_area_folder).path_join(sub_folder_name)
		
		# Automatically create the missing target directories if they don't exist yet
		if not DirAccess.dir_exists_absolute(sub_dir):
			DirAccess.make_dir_recursive_absolute(sub_dir)
			
		var save_path = sub_dir.path_join(c_name.validate_filename() + ".tres")

		# --- INSTANTIATE OR IN-PLACE LOAD YOUR CUSTOM COMPOSITION OBJECT ---
		# NOTE: Change 'EncounterComposition' below to match your actual script class name!
		var res: CombatComposition = load(save_path) if FileAccess.file_exists(save_path) else CombatComposition.new()
		
		# --- EXTRACT AND ASSIGN SPREADSHEET VARIABLES ---
		res.encounter_name = c_name
		
		# Optional boilerplate: Parsing subsequent row indices for enemy lineups into arrays
		var combatants_list: Array[String] = []
		for idx in range(2, row.size()):
			var enemy_entry = row[idx].strip_edges()
			if enemy_entry != "":
				combatants_list.append(enemy_entry)
		
		# Assuming your composition class has an array property tracking strings/rosters:
		# res.enemy_roster = combatants_list
		
		# --- SAVE GENERATED RESOURCE WITH MEMORY PROTECTION FLAGS ---
		res.take_over_path(save_path)
		var save_status = ResourceSaver.save(res, save_path, ResourceSaver.FLAG_REPLACE_SUBRESOURCE_PATHS)
		
		if save_status == OK:
			print("Successfully Synced Composition: ", c_name)
		else:
			printerr("Failed to save encounter composition file. Error code: ", save_status)
			
	file.close()
	
	# --- 6. FINAL POST-IMPORT INTERFACE SYNC ---
	var efs_final = EditorInterface.get_resource_filesystem()
	efs_final.scan()
	while efs_final.is_scanning():
		await Engine.get_main_loop().process_frame
		
	print("--- Composition Import Task Finished ---")
		
func run_composition_generation_loop() -> void:
	var efs_reset = EditorInterface.get_resource_filesystem()
	efs_reset.scan()
	while efs_reset.is_scanning():
		await Engine.get_main_loop().process_frame
	print("============ [TOOL] COMPILING ENCOUNTER RESOURCES ============")
	
	if encounter_tab_gids.is_empty():
		printerr("Composition Importer: No encounter tabs configured.")
		return
		
	for i in range(encounter_tab_gids.size()):
		var calculated_local_path = "res://Scripts/Data/CSV/Encounters - Area_" + str(i + 1) + ".csv"
		
		if not FileAccess.file_exists(calculated_local_path):
			printerr("Composition Importer: File missing on disk, run Sync tool button first! Path: ", calculated_local_path)
			continue
			
		compositions_csv_path = calculated_local_path 
		print("Processing composition compilation for: ", calculated_local_path.get_file())
		await generate_compositions()
		
	print("============ COMPOSITION RESOURCE COMPILATION COMPLETE ============")
	
func find_behavior_globally(behavior_name: String) -> Behavior:
	var cleaned_name: String = behavior_name.strip_edges().to_lower()
	if cleaned_name == "": return null
	
	var target_filename: String = cleaned_name + ".tres"
	
	if behavior_cache.has(target_filename):
		return load(behavior_cache[target_filename]) as Behavior
			
	printerr("Could not find Behavior resource: '", behavior_name, "'")
	return null

func _get_all_files_on_disk(path: String, file_list: Array[String]) -> void:
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if dir.current_is_dir():
				if not file_name.begins_with("."): # Skip hidden folders like .godot
					_get_all_files_on_disk(path.path_join(file_name), file_list)
			else:
				file_list.append(path.path_join(file_name))
			file_name = dir.get_next()
		dir.list_dir_end()
	
func download_csv_from_drive():
	if google_sheet_heroes_id == "" or google_sheet_encounters_id == "":
		printerr("Sync Action: Google Sheet IDs are missing!")
		return

	# FIXED: Changed from "://google.com" to the proper pure domain string
	var host = "docs.google.com"

	# --- 1. DOWNLOAD MASTER HEROES CSV ---
	if csv_path != "":
		var heroes_url = "/spreadsheets/d/" + google_sheet_heroes_id + "/export?format=csv&gid=" + google_sheet_gid
		print("Sync Action: Downloading Master Heroes CSV...")
		await _perform_http_download(host, heroes_url, 5, csv_path)
	
	# --- 2. LOOP DOWNLOAD COMPOSITIONS VIA AUTOMATIC INDEXING ---
	if encounter_tab_gids.is_empty():
		push_warning("Sync Action: No encounter GID tabs provided.")
	else:
		for i in range(encounter_tab_gids.size()):
			var target_gid = encounter_tab_gids[i].strip_edges()
			if target_gid == "": 
				continue
			
			var calculated_local_path = "res://Scripts/Data/CSV/Encounters - Area_" + str(i + 1) + ".csv"
			var url_path = "/spreadsheets/d/" + google_sheet_encounters_id + "/export?format=csv&gid=" + target_gid
			
			print("Sync Action: Fetching Area %d [GID: %s] -> %s" % [(i + 1), target_gid, calculated_local_path])
			await _perform_http_download(host, url_path, 5, calculated_local_path)
			
	print("--- Sync Action: All CSV data downloads successfully processed ---")

func _perform_http_download(host: String, url_path: String, redirect_limit: int, target_save_path: String):
	if redirect_limit <= 0:
		printerr("Importer: Too many redirects!")
		return

	print("Importer: Connecting to: ", host)
	var http = HTTPClient.new()
	
	var err = http.connect_to_host(host, 443, TLSOptions.client())
	if err != OK:
		printerr("Importer: Connection error: ", err)
		return

	while http.get_status() == HTTPClient.STATUS_CONNECTING or http.get_status() == HTTPClient.STATUS_RESOLVING:
		http.poll()
		OS.delay_msec(50)

	http.request(HTTPClient.METHOD_GET, url_path, [])

	while http.get_status() == HTTPClient.STATUS_REQUESTING:
		http.poll()
		OS.delay_msec(50)

	if http.has_response():
		var code = http.get_response_code()
		print("Importer: Response Code: ", code)

		if code == 301 or code == 302 or code == 307 or code == 308:
			var headers = http.get_response_headers_as_dictionary()
			var location = ""
		
			for key in headers:
				if key.to_lower() == "location":
					location = headers[key]
					break
		
			if location != "":
				print("Importer: Redirecting to: ", location)
			
				var next_host = host
				var next_path = url_path
			
				if location.begins_with("http"):
					var stripped_url = location.replace("https://", "").replace("http://", "")
					var first_slash = stripped_url.find("/")
					next_host = stripped_url.substr(0, first_slash)
					next_path = stripped_url.substr(first_slash)
				else:
					next_path = location

				http.close()
				# CRUCIAL: Pass target_save_path into the redirect call!
				_perform_http_download(next_host, next_path, redirect_limit - 1, target_save_path)
				return

		var response_body = PackedByteArray()
		while http.get_status() == HTTPClient.STATUS_BODY:
			http.poll()
			var chunk = http.read_response_body_chunk()
			if chunk.size() > 0:
				response_body.append_array(chunk)
			else:
				OS.delay_msec(10)
		
		if code == 200:
			# CHANGED: Open target_save_path instead of the old hardcoded csv_path
			var file = FileAccess.open(target_save_path, FileAccess.WRITE)
			if file:
				file.store_buffer(response_body)
				file.close()
				EditorInterface.get_resource_filesystem().scan()
				print("Importer: CSV Sync Successful for %s! [%s]" % [target_save_path.get_file(), Time.get_time_string_from_system()])
			else:
				printerr("Importer: Could not write to file path: ", target_save_path)
		else:
			printerr("Importer: Failed with code ", code, ". Body received: ", response_body.get_string_from_utf8())
	
	http.close()
