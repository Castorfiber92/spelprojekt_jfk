extends CombatEvent
class_name CombatBossEvent

func trigger_interaction(player_node: Node) -> void:
	visited = true
	print("Initiating boss battle.")
	super.trigger_interaction(player_node) # Run the default combat code
