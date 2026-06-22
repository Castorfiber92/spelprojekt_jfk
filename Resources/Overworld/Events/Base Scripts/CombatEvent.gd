extends MapEvent
class_name CombatEvent

func trigger_interaction(player_node: Node) -> void:
	visited = true
	print("Initiating battle.")
