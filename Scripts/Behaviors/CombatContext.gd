class_name CombatContext

var manager: CombatManager
var source: HeroSlot
var targets: Array[HeroSlot]
var damage_dealt_map: Dictionary = {} # Key: HeroSlot, Value: int (actual damage taken)
var heal_dealt_map : Dictionary = {} # Key: HeroSlot, Value: int (actual heal taken)
var lethal_targets: Array[HeroSlot] = [] # Tracks who hit 0 HP from this action

func _init(_source: HeroSlot, _targets: Array[HeroSlot] = [], _manager: Node = null):
	self.source = _source
	self.targets = _targets
	self.manager = _manager
	
func record_damage(target_slot: HeroSlot, amount: int, is_lethal: bool) -> void:
	damage_dealt_map[target_slot] = amount
	if is_lethal and not lethal_targets.has(target_slot):
		lethal_targets.append(target_slot)

func record_heal(target_slot: HeroSlot, amount: int) -> void:
	heal_dealt_map[target_slot] = amount

func get_damage_dealt_to(target_slot: HeroSlot) -> int:
	return damage_dealt_map.get(target_slot, 0)

func get_heal_dealt_to(target_slot: HeroSlot) -> int:
	return heal_dealt_map.get(target_slot, 0)

func resolve_targets(behavior: Behavior, combat_manager: CombatManager) -> Array[HeroSlot]:
	var candidates: Array[HeroSlot] = []
	var source_team: Enums.Team = Enums.Team.FRIEND
	source_team = behavior.owner_hero.team

	# Match against team enum configuration
	match behavior.data.target_team:
		Enums.Team.SELF:
			candidates = [source]
		Enums.Team.FRIEND:
			# Automatically passes the inner hero object to existing helper
			candidates = combat_manager.get_friendly_slots(source_team)
		Enums.Team.ENEMY:
			# Automatically passes the inner hero object to existing helper
			candidates = combat_manager.get_enemy_slots(source_team)
		
	# Runs range rules, row protections, and single/multi target hooks
	return behavior.get_valid_targets(source, candidates)
