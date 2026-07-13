class_name CombatContext

var manager: CombatManager
var source: HeroSlot
var targets: Array[HeroSlot]
	
func _init(_source: HeroSlot, _targets: Array[HeroSlot] = [], _manager: Node = null):
	self.source = _source
	self.targets = _targets
	self.manager = _manager
	
func resolve_targets(behavior: BehaviorBase, combat_manager: CombatManager) -> Array[HeroSlot]:
	var candidates: Array[HeroSlot] = []
	
	# Match against team enum configuration
	match behavior.target_team:
		Enums.Team.SELF:
			candidates = [source]
		Enums.Team.FRIEND:
			# Automatically passes the inner hero object to existing helper
			candidates = combat_manager.get_friendly_slots(source.hero)
		Enums.Team.ENEMY:
			# Automatically passes the inner hero object to existing helper
			candidates = combat_manager.get_enemy_slots(source.hero)
		
	# Runs range rules, row protections, and single/multi target hooks
	return behavior.get_valid_targets(source, candidates)
