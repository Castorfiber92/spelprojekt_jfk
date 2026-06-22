extends MapEvent
class_name EncounterEvent

func trigger_interaction(player_node: Node) -> void:
	visited = true
	print("Initiating encounter.")
