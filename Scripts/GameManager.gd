extends Node2D

var _saved_player_cell: Vector2i = Vector2i(-999, -999)
var _saved_map_events: Dictionary = {}
var _has_saved_state: bool = false

## Saves the entire map grid memory layout before changing scenes
func save_map_state(player_cell: Vector2i, active_map_events: Dictionary) -> void:
	_saved_player_cell = player_cell
	_saved_map_events = active_map_events.duplicate(true) # Deep copy to preserve states
	_has_saved_state = true
	print("GameManager: Overworld state successfully cached in memory.")

## Returns true if the player is returning from combat/shop and has an active map layout
func has_saved_map_state() -> bool:
	return _has_saved_state

## Fetches the cached player grid cell coordinate
func get_saved_player_cell() -> Vector2i:
	return _saved_player_cell

## Fetches the cached dictionary containing all event data states
func get_saved_map_events() -> Dictionary:
	return _saved_map_events

## Call this only if you want to reset the overworld entirely (e.g., game over or entering a new act)
func clear_map_state() -> void:
	_saved_player_cell = Vector2i(-999, -999)
	_saved_map_events.clear()
	_has_saved_state = false

# BELOW IS FOR TESTING ONLY
func _unhandled_input(event: InputEvent) -> void:
	# Check if the player pressed the Escape key
	if event is InputEventKey and event.pressed and OS.is_debug_build() and event.keycode == KEY_ESCAPE:
		# Safety Guard: Only allow the shortcut if we have a valid map state to return to
		var current_scene = get_tree().current_scene
		if current_scene:
			var scene_file = current_scene.scene_file_path.get_file().to_lower()
			# Bails out instantly if we are already inside the Overworld scene
			if "overworld" in scene_file or current_scene.name.to_lower() == "overworldmanager":
				return 
		
		if has_saved_map_state():
			# Check if the active scene has our safe cleanup function written on it
			if current_scene and current_scene.has_method("emergency_exit_to_overworld"):
				current_scene.emergency_exit_to_overworld()
			else:
				print("GameManager HOTKEY: Escape pressed! Bypassing scene loop and returning to Overworld...")
				get_tree().change_scene_to_file("res://Scripts/Overworld/OverworldManager.tscn")
