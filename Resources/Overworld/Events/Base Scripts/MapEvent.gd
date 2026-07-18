extends Resource
class_name MapEvent

enum EventType { COMBAT, TAVERN, SHOP, ENCOUNTER, BOSS }
@export var type: EventType
var visited: bool = false
var unique_id: int = 0

# Update this variable/function for each event to a specific tile/graphic, rn we do nothing
@export var cleared_tile_coords: Vector2i = Vector2i(1, 0)

func trigger_interaction(player_node: Node) -> void:
	# Virtual method: overridden by specific sub-classes
	visited = true
	GameEvents.map_event_triggered.emit(self)
