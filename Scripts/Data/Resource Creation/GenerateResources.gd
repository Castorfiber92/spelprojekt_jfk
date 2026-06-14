@tool
extends Node

@export_file("*.csv") var csv_path: String
@export_dir var output_dir: String = "res://Resources/Heroes/"

@export_group("Generate Functions")
@export_tool_button("Generate Heroes","Callable") var generate_heroes_action = generate_heroes 
@export_tool_button("Link Sprites to Existing Heroes","Callable") var link_sprites_action = link_sprites_to_heroes

@export_group("Google Drive Sync")
## The ID from your Google Sheet URL
@export var google_sheet_id: String = "17J7sFikfk8IrrhA2Krcp29_qytfdY_f5aiZjjxtkmh4"
## The GID (Sheet Page ID) - 0 for the first sheet
@export var google_sheet_gid: String = "0"
@export_tool_button("Sync CSV from Drive", "Callable") var sync_drive_action = download_csv_from_drive

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
	var root = efs.get_filesystem()
	
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
					
		# Check if a matching sprite file already exists using your helper
		var sprite_filename = h_name.to_lower().replace(" ", "_") + "_sprites.tres"
		var sprite_path = _find_file_in_cache(root, sprite_filename) # 'root' comes from efs.get_filesystem()
		
		if sprite_path != "":
			res.sprites = load(sprite_path) as SpriteFrames

		# Save the resource
		ResourceSaver.save(res, save_path)
		print("Successfully Synced: ", h_name)
			
	# Close the file
	file.close()
	print("--- Import Task Finished ---")

func link_sprites_to_heroes():
	# Check that we are not running the game
	if not Engine.is_editor_hint():
		return
	
	# Pre-scan the filesystem to ensure Godot's cache is up to date
	print("Hero Importer: Starting Sprite Linking Task...")
	EditorInterface.get_resource_filesystem().scan()
	
	var efs = EditorInterface.get_resource_filesystem()
	var root = efs.get_filesystem()
	
	# Open the CSV file to find which heroes we need to look for
	if csv_path == "" or not FileAccess.file_exists(csv_path):
		printerr("Hero Importer: Invalid CSV path for sprite linking!")
		return
		
	var file = FileAccess.open(csv_path, FileAccess.READ)
	var _headers = file.get_csv_line() 
	var base_graphics_dir = "res://Graphics/Hero Sprites/"
	var updated_count = 0
	
	while not file.eof_reached():
		var row = file.get_csv_line()
		if row.size() < 3: continue # Need at least name and tribe to build the path
		
		var h_name = row[0].strip_edges()
		if h_name == "": continue
		
		var tribe_string = row[2].strip_edges().to_lower()
		var tribe_folder_name = tribe_string.capitalize()
		
		# Build the exact path where this hero's .tres resource lives
		var hero_file_path = output_dir.path_join(tribe_folder_name).path_join(h_name.validate_filename() + ".tres")
		var sprite_filename = h_name.to_lower().replace(" ", "_") + "_sprites.tres"
		var expected_sprite_path = base_graphics_dir.path_join(tribe_folder_name).path_join(sprite_filename)
		
		# Only proceed if the hero data resource actually exists
		if FileAccess.file_exists(hero_file_path):
			var res: HeroData = load(hero_file_path)
			
			# Check if the sprite file actually exists in that specific tribe folder
			if FileAccess.file_exists(expected_sprite_path):
				var sprite_res = load(expected_sprite_path) as SpriteFrames
				
				if res.sprites != sprite_res:
					res.sprites = sprite_res
					ResourceSaver.save(res, hero_file_path)
					print("Linked sprite to existing hero: ", h_name)
					updated_count += 1
			else:
				print("Hero Importer: No sprite asset found at: ", expected_sprite_path)
				
	file.close()
	print("--- Sprite Linking Finished ---")


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

func download_csv_from_drive():
	if google_sheet_id == "":
		printerr("Hero Importer: No ID provided!")
		return

	var host = "docs.google.com"
	var url_path = "/spreadsheets/d/" + google_sheet_id + "/export?format=csv&gid=" + google_sheet_gid
	
	# Start the process with a redirect limit of 5
	_perform_http_download(host, url_path, 5)

func _perform_http_download(host: String, url_path: String, redirect_limit: int):
	if redirect_limit <= 0:
		printerr("Hero Importer: Too many redirects!")
		return

	print("Hero Importer: Connecting to: ", host)
	var http = HTTPClient.new()
	
	# Connect to the host
	var err = http.connect_to_host(host, 443, TLSOptions.client())
	if err != OK:
		printerr("Hero Importer: Connection error: ", err)
		return

	# Wait for connection
	while http.get_status() == HTTPClient.STATUS_CONNECTING or http.get_status() == HTTPClient.STATUS_RESOLVING:
		http.poll()
		OS.delay_msec(50)

	# Send the GET request
	http.request(HTTPClient.METHOD_GET, url_path, [])

	# Wait for response headers
	while http.get_status() == HTTPClient.STATUS_REQUESTING:
		http.poll()
		OS.delay_msec(50)

	if http.has_response():
		var code = http.get_response_code()
		print("Hero Importer: Response Code: ", code)

		# 1. Handle Redirects (Include 307 and 308)
		if code == 301 or code == 302 or code == 307 or code == 308:
			var headers = http.get_response_headers_as_dictionary()
			var location = ""
		
			# Headers can be "Location" or "location" 
			for key in headers:
				if key.to_lower() == "location":
					location = headers[key]
					break
		
			if location != "":
				print("Hero Importer: Redirecting to: ", location)
			
				# Ensure we handle absolute URLs from the redirect
				var next_host = host
				var next_path = url_path
			
				if location.begins_with("http"):
					var stripped_url = location.replace("https://", "").replace("http://", "")
					var first_slash = stripped_url.find("/")
					next_host = stripped_url.substr(0, first_slash)
					next_path = stripped_url.substr(first_slash)
				else:
					next_path = location # Relative redirect

				http.close()
				_perform_http_download(next_host, next_path, redirect_limit - 1)
				return

		# 2. Handle Actual Data (200 OK)
		var response_body = PackedByteArray()
		while http.get_status() == HTTPClient.STATUS_BODY:
			http.poll()
			var chunk = http.read_response_body_chunk()
			if chunk.size() > 0:
				response_body.append_array(chunk)
			else:
				OS.delay_msec(10)
		
		# Only save if we actually got a 200 OK
		if code == 200:
			var file = FileAccess.open(csv_path, FileAccess.WRITE)
			if file:
				file.store_buffer(response_body)
				file.close()
				EditorInterface.get_resource_filesystem().scan()
				print("Hero Importer: CSV Sync Successful! [%s]" % Time.get_time_string_from_system())
			else:
				printerr("Hero Importer: Could not write to file path.")
		else:
			printerr("Hero Importer: Failed with code ", code, ". Body received: ", response_body.get_string_from_utf8())
	
	http.close()
