extends MapEvent
class_name CombatEvent

enum CombatType {NORMAL, ELITE, BOSS}
@export var combat_type = CombatType.NORMAL
func trigger_interaction(player_node: Node) -> void:
	# Virtual method: overridden by specific sub-classes
	visited = true
	RunManager.roll_next_encounter(combat_type)
	GameEvents.map_event_triggered.emit(self)
