extends Node2D

class HexAStar extends AStar2D:
	var manager_ref: Node2D 
	var explicit_target_id: int = -1 
	
	func _compute_cost(from_id: int, to_id: int) -> float:
		if to_id != explicit_target_id:
			var target_x = to_id >> 32
			var target_y = to_id & 0xFFFFFFFF
			var target_cell = Vector2i(target_x, target_y)
			
			# NEW LOGIC ENTRY: Only block if the event exists AND has NOT been visited yet!
			if manager_ref.map_events.has(target_cell):
				var event: MapEvent = manager_ref.map_events[target_cell]
				if not event.visited:
					return 999999.0 # Acts like a wall for active events
				
		return 1.0 # Safe to walk over if empty or visited
		
	func _estimate_cost(from_id: int, to_id: int) -> float:
		return get_point_position(from_id).distance_to(get_point_position(to_id))


@onready var tile_map_layer: TileMapLayer = $TileMapLayer
@onready var player: CharacterBody2D = $Player
@onready var line_2d: Line2D = $Line2D # Direct reference to our new visual line drawer
var selected_cell: Vector2i = Vector2i(-999, -999)

var astar: AStar2D = HexAStar.new()
var current_path: Array[Vector2i] = []
var is_moving: bool = false
var map_events: Dictionary = {} 

# Runtime state tracking variables for our double-click logic
var current_preview_cells: Array[Vector2i] = []
var last_hovered_cell: Vector2i = Vector2i(-999, -999)

func _ready() -> void:
	generate_map_events()
	initialize_navigation_grid()
	snap_player_to_start()
	line_2d.clear_points() # Make sure the line starts completely empty

func get_cell_id(cell: Vector2i) -> int:
	return (cell.x << 32) | (cell.y & 0xFFFFFFFF)

func initialize_navigation_grid() -> void:
	astar.clear()
	astar.manager_ref = self # Feed the manager reference to our custom class
	
	var active_cells = tile_map_layer.get_used_cells()
	
	# 1. Register points
	for cell in active_cells:
		var point_id = get_cell_id(cell) 
		var cell_position = tile_map_layer.map_to_local(cell)
		astar.add_point(point_id, cell_position)
	
	# 2. Build connection bridges UNIFORMLY everywhere
	for cell in active_cells:
		var current_id = get_cell_id(cell)
		var surrounding_neighbors = tile_map_layer.get_surrounding_cells(cell)
		
		for neighbor in surrounding_neighbors:
			if neighbor in active_cells:
				var neighbor_id = get_cell_id(neighbor)
				astar.connect_points(current_id, neighbor_id, true) # Always connect


func snap_player_to_start() -> void:
	var current_cell = tile_map_layer.local_to_map(player.global_position)
	player.global_position = tile_map_layer.map_to_local(current_cell)

func calculate_path_preview(target_cell: Vector2i) -> void:
	line_2d.clear_points()
	current_preview_cells.clear()
	
	var player_cell = tile_map_layer.local_to_map(player.global_position)
	var start_id = get_cell_id(player_cell)
	var target_id = get_cell_id(target_cell)
	
	if astar.has_point(start_id) and astar.has_point(target_id):
		# Tell our custom pathfinder class what the player clicked on
		astar.explicit_target_id = target_id
		
		# Request the path lines
		var pixel_path = astar.get_point_path(start_id, target_id)
		
		# Reset the explicit target tracker back to safety
		astar.explicit_target_id = -1
			
		# Populate our preview arrays and feed the points to our Line2D node
		if pixel_path.size() > 0:
			for point in pixel_path:
				current_preview_cells.append(tile_map_layer.local_to_map(point))
				line_2d.add_point(point)

func _unhandled_input(event: InputEvent) -> void:
		# If player clicks Right Mouse Button, clear the line and cancel selection
	if event.is_action_pressed("ui_cancel") or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed):
		line_2d.clear_points()
		current_preview_cells.clear()
		selected_cell = Vector2i(-999, -999)
	# Accept inputs only when the player isn't actively walking
	if event.is_action_pressed("click_to_move") and not is_moving:
		var mouse_pos = get_global_mouse_position()
		var target_cell = tile_map_layer.local_to_map(mouse_pos)
		
		# --- CONDITION A: PLAYER CONFIRMED MOVEMENT (DOUBLE CLICK) ---
		if event is InputEventMouseButton and event.double_click:
			# If they double click the currently selected target, start marching!
			if target_cell == selected_cell and current_preview_cells.size() > 1:
				execute_cached_path()
				return # Exit early
		
		# --- CONDITION B: PLAYER CHANGED TARGET OR FIRST CLICK ---
		# If they click a different cell, or click the same cell a second time slowly
		if target_cell != selected_cell:
			selected_cell = target_cell
			calculate_path_preview(target_cell)
		else:
			# Strategy Game Comfort Check: If they click the exact same hex a second time 
			# slowly, treat it like a movement confirmation anyway.
			if current_preview_cells.size() > 1:
				execute_cached_path()

# HELPER FUNCTION: Cleans up data and transfers the track to the active walker queue
func execute_cached_path() -> void:
	current_path = current_preview_cells.duplicate()
	current_path.remove_at(0) # Skip the current hex position
	
	line_2d.clear_points() # Clear visual paths during transit
	selected_cell = Vector2i(-999, -999) # Reset target tracking
	start_movement_loop()
	
func start_movement_loop() -> void:
	is_moving = true
	move_to_next_hex()

func move_to_next_hex() -> void:
	if current_path.is_empty():
		is_moving = false
		return
		
	var next_cell = current_path.pop_front()
	var target_pixel_pos = tile_map_layer.map_to_local(next_cell)
	
	var tween = create_tween()
	tween.tween_property(player, "global_position", target_pixel_pos, 0.25) 
	
	# When the step finishes
	tween.finished.connect(func():
		# --- BOSS PROGRESSION HOOK ---
		# Every time the player completes a step onto a hex, increment the counter
		# Preloads.total_steps_taken += 1, this counter is not yet implemented. Leave it for later 
		# if we want it.
		print("Total steps taken this game: ", Preloads.total_steps_taken)
		# ---------------------------------
		if map_events.has(next_cell):
			var event: MapEvent = map_events[next_cell]
			
			# --- THE PASSIVE TRAVERSAL FIX ---
			# If the event has already been visited, DO NOT trigger it again!
			# Simply allow the player to pass through seamlessly like normal grass.
			if not event.visited:
				# Trigger the custom print statement/logic (sets visited = true)
				event.trigger_interaction(player)
				
				# Swap the visual tile to your grass/empty cell graphic
				var source_id = tile_map_layer.get_cell_source_id(next_cell)
				tile_map_layer.set_cell(next_cell, source_id, event.cleared_tile_coords)
				
				# Force a full stop at the interaction center
				current_path.clear()
				is_moving = false
				current_preview_cells.clear()
				selected_cell = Vector2i(-999, -999) 
				return 
			
		# If there's no event, or the event was already visited, continue walking
		move_to_next_hex()
	)

func generate_map_events():
	map_events.clear()
	randomize()
	for cell in tile_map_layer.get_used_cells():
		var tile_data = tile_map_layer.get_cell_tile_data(cell)
		if not tile_data: continue
		if not tile_data.has_custom_data("event_resource"): continue
		var resource_name: String = tile_data.get_custom_data("event_resource")
		if not resource_name.is_empty():
			var resource_template = Preloads.get(resource_name)
			if resource_template:
				var new_event: MapEvent = resource_template.duplicate()
				new_event.unique_id = randi()
				new_event.visited = false
				map_events[cell] = new_event

func remove_event_after_interaction(cell: Vector2i):
	if map_events.has(cell):
		map_events.erase(cell) # Automatically unblocks the pathfinder next calculation frame!
