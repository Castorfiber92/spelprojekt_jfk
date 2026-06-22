extends MapEvent
class_name TavernEvent

func trigger_interaction(player_node: Node) -> void:
	visited = true
	print("Initiating tavern.")
