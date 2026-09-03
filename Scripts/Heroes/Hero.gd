extends Node
class_name Hero

var hero_data : HeroData
var current_tier : HeroData.HeroTier
var current_HP : int
var maximum_HP : int
@export var team: Enums.Team = Enums.Team.FRIEND

var has_acted = false

var stat_modifiers: Array[Behavior] = []   # Elements whose data.type == STAT
var active_passives: Array[Behavior] = []  # Elements whose data.type == PASSIVE, BUFF, ACTIVE

var event_listeners: Dictionary = {
	Enums.TriggerEvent.ON_START_OF_BATTLE: [],
	Enums.TriggerEvent.ON_TURN_START: [],
	Enums.TriggerEvent.ON_EXECUTE_ACTION: [],
	Enums.TriggerEvent.ON_TURN_END: [],
	Enums.TriggerEvent.ON_ROUND_END: [],
	Enums.TriggerEvent.ON_DAMAGE_TAKEN: [],
	Enums.TriggerEvent.ON_DAMAGE_DEALT: [],
	Enums.TriggerEvent.ON_DEATH: []
}

static func create(data: HeroData) -> Hero:
	var new_hero = Hero.new()
	new_hero.hero_data = data.duplicate(true) as HeroData
	new_hero.initialize_data()
	return new_hero

func _enter_tree() -> void:
	# Defensive design check: Safely isolate duplicates if an edge-case double connection occurs
	disconnect_signals()
	
	GameEvents.battle_started.connect(_on_battle_started)
	GameEvents.round_ended.connect(_on_round_ended)
	GameEvents.turn_started.connect(_on_turn_started)
	GameEvents.turn_ended.connect(_on_turn_ended)
	GameEvents.action_execution_requested.connect(_on_action_execution_requested)


# Triggers unconditionally the exact millisecond the node leaves a slot parent
func _exit_tree() -> void:
	disconnect_signals()


## Helper routing component to ensure network cleanliness across scene transitions
func disconnect_signals() -> void:
	if GameEvents.battle_started.is_connected(_on_battle_started): GameEvents.battle_started.disconnect(_on_battle_started)
	if GameEvents.round_ended.is_connected(_on_round_ended):       GameEvents.round_ended.disconnect(_on_round_ended)
	if GameEvents.turn_started.is_connected(_on_turn_started):     GameEvents.turn_started.disconnect(_on_turn_started)
	if GameEvents.turn_ended.is_connected(_on_turn_ended):         GameEvents.turn_ended.disconnect(_on_turn_ended)
	if GameEvents.action_execution_requested.is_connected(_on_action_execution_requested): GameEvents.action_execution_requested.disconnect(_on_action_execution_requested)
	
func _on_battle_started(manager: CombatManager) -> void: trigger_behavior_event(Enums.TriggerEvent.ON_START_OF_BATTLE, [], manager)
func _on_turn_started(slot: HeroSlot, combat_manager: CombatManager) -> void:
	if slot.hero == self:
		trigger_behavior_event(Enums.TriggerEvent.ON_TURN_START, [], combat_manager)

func _on_turn_ended(slot: HeroSlot, combat_manager: CombatManager) -> void:
	if slot.hero == self:
		trigger_behavior_event(Enums.TriggerEvent.ON_TURN_END, [], combat_manager)

func _on_action_execution_requested(slot: HeroSlot, combat_manager: CombatManager) -> void:
	if slot.hero == self:
		# FIXED: Passes the explicit manager reference provided directly by the signal channel!
		trigger_behavior_event(Enums.TriggerEvent.ON_EXECUTE_ACTION, [], combat_manager)

func initialize_data() -> void:
	# Explicitly wipe and ensure the dictionary arrays are ready in memory first!
	event_listeners = {
		Enums.TriggerEvent.ON_START_OF_BATTLE: [],
		Enums.TriggerEvent.ON_TURN_START: [],
		Enums.TriggerEvent.ON_EXECUTE_ACTION: [],
		Enums.TriggerEvent.ON_TURN_END: [],
		Enums.TriggerEvent.ON_ROUND_END: [],
		Enums.TriggerEvent.ON_DAMAGE_TAKEN: [],
		Enums.TriggerEvent.ON_DAMAGE_DEALT: [],
		Enums.TriggerEvent.ON_DEATH: []
	}
	
	if hero_data.base_action:
		add_behavior(Behavior.create(hero_data.base_action))
	for ability_res in hero_data.abilities:
		add_behavior(Behavior.create(ability_res))
	reset_temporary_data()

func prepare_for_combat():
	reset_temporary_data()
	clear_temporary_buffs()

func reset_temporary_data():
	current_HP = hero_data.base_HP
	maximum_HP = current_HP
	has_acted = false
	
func clear_temporary_buffs():
	# Filter out anything that isn't a temporary buff, keeping only permanent skills/traits
	active_passives = active_passives.filter(
		func(b): return b.data.type != BehaviorData.BehaviorType.BUFF
	)

func _on_round_ended(manager: CombatManager) -> void:
	var local_slot = manager.hero_to_slot_map.get(self)
	if local_slot == null: return
	var context = CombatContext.new(local_slot, [], manager)
	trigger_behavior_event(Enums.TriggerEvent.ON_ROUND_END, context, manager)

func take_damage(damage : int, source : HeroSlot) -> void:
	var active_max_hp = get_stat(Enums.StatType.MAX_HP)
	current_HP = clamp(current_HP - damage, 0, active_max_hp)
	print(hero_data.name, " takes ", damage, " damage from ", source.hero.hero_data.name if source and source.hero else "unknown")
	
	GameEvents.hero_damaged.emit(self, source, damage)

		
func heal_HP(value : int, source : HeroSlot) -> void:
	var active_max_hp = get_stat(Enums.StatType.MAX_HP)
	var old_hp = current_HP
	current_HP = clamp(current_HP + value, 0, active_max_hp)
	var actual_healed = current_HP - old_hp
	print(hero_data.name, " heals for ", actual_healed)
	
	GameEvents.hero_healed.emit(self, source, actual_healed)

func can_act() -> bool:
	# If any logic behavior in our active passives array blocks actions (like Stun), return false
	return not active_passives.any(func(behavior): return behavior.data.blocks_action)

func add_behavior(new_behavior: Behavior) -> bool:
	if new_behavior == null: return false
	new_behavior.owner_hero = self
	
	if new_behavior.data.type == BehaviorData.BehaviorType.STAT:
		stat_modifiers.append(new_behavior)
		return true
		
	if new_behavior.data.type == BehaviorData.BehaviorType.BUFF:
		for existing in active_passives:
			if existing.data.name == new_behavior.data.name:
				if existing.data.base_stacks == 0 or new_behavior.data.base_stacks == 0: return false
				if existing.data.add_stacks: existing.current_stacks += new_behavior.current_stacks
				else: existing.current_stacks = max(existing.current_stacks, new_behavior.current_stacks)
				return true

	# AUTOMATED SUBSCRIPTION: Scans the attached script file code blocks directly!
	var data_res = new_behavior.data
	if data_res.has_method("on_start_of_battle"): event_listeners[Enums.TriggerEvent.ON_START_OF_BATTLE].append(new_behavior)
	if data_res.has_method("on_turn_start"):     event_listeners[Enums.TriggerEvent.ON_TURN_START].append(new_behavior)
	if data_res.has_method("on_execute_action"):  event_listeners[Enums.TriggerEvent.ON_EXECUTE_ACTION].append(new_behavior)
	if data_res.has_method("on_turn_end"):       event_listeners[Enums.TriggerEvent.ON_TURN_END].append(new_behavior)
	if data_res.has_method("on_round_end"):      event_listeners[Enums.TriggerEvent.ON_ROUND_END].append(new_behavior)
	if data_res.has_method("on_damage_taken"):   event_listeners[Enums.TriggerEvent.ON_DAMAGE_TAKEN].append(new_behavior)
	if data_res.has_method("on_damage_dealt"):   event_listeners[Enums.TriggerEvent.ON_DAMAGE_DEALT].append(new_behavior)
	if data_res.has_method("on_death"):          event_listeners[Enums.TriggerEvent.ON_DEATH].append(new_behavior)
				
	active_passives.append(new_behavior)
	return true
		
func remove_behavior(behavior_instance: Behavior) -> void:
	if behavior_instance == null: return
	if behavior_instance.data.type == BehaviorData.BehaviorType.STAT:
		stat_modifiers.erase(behavior_instance)
	else:
		active_passives.erase(behavior_instance)
		# Cleanly erase them out of the active listener matrix lines as well
		for event_type in event_listeners:
			event_listeners[event_type].erase(behavior_instance)



func trigger_behavior_event(event_type: Enums.TriggerEvent, source_context: Variant, combat_manager: CombatManager) -> void:
	if combat_manager == null: return
	var local_hero_slot = combat_manager.hero_to_slot_map.get(self)
	if local_hero_slot == null: return

	# Zero searching loops! Fetches ONLY the explicit behaviors already sorted into this index
	var active_listeners = event_listeners.get(event_type, [])
	
	for behavior in active_listeners:
		var target_context = CombatContext.new(local_hero_slot, [], combat_manager)
		target_context.targets = target_context.resolve_targets(behavior, combat_manager)
		
		# Directly route to the precise functional hook name inside your script documents
		behavior.route_to_matching_hook(event_type, target_context, source_context)

func get_stat(stat_type: Enums.StatType) -> Variant:
	var calculated_stats = {
		Enums.StatType.SPEED: float(hero_data.base_speed),
		Enums.StatType.RANGE: float(hero_data.base_range),
		Enums.StatType.DAMAGE: float(hero_data.base_damage),
		Enums.StatType.MAX_HP: float(hero_data.base_HP),
		Enums.StatType.CRIT: hero_data.base_crit_chance
	}
	for b in stat_modifiers:
		if b.data.has_method("_execute_stat_modification"):
			b.data._execute_stat_modification(calculated_stats)
			
	var final_value = calculated_stats.get(stat_type, 0.0)
	match stat_type:
		Enums.StatType.DAMAGE, Enums.StatType.SPEED, Enums.StatType.MAX_HP:
			return int(maxf(1.0, final_value))
		Enums.StatType.RANGE:
			return int(maxf(0.0, final_value))
		Enums.StatType.CRIT:
			return clampf(final_value, 0.0, 1.0)
	return final_value
	
func get_behaviors() -> Array[Behavior]:
	# Combines both for the UI layer to draw status icons smoothly
	return active_passives + stat_modifiers
