extends Node
class_name Hero

var hero_data : HeroData
var current_tier : Enums.HeroTier

@export var current_enchantments : Array[Enchantment]
@export var team: Enums.Team = Enums.Team.FRIEND

var has_acted = false

var stat_modifiers: Array[Behavior] = []   # Elements whose data.type == STAT
var active_passives: Array[Behavior] = []  # Elements whose data.type == PASSIVE, BUFF, ACTIVE

## Stores the clean, permanent stats scaled by level-ups
var runtime_base_stats: Dictionary = {}

## Stores the temporary active modifications or current values during battle
var current_stats: Dictionary = {}

static func create(data: HeroData) -> Hero:
	var new_hero = Hero.new()
	new_hero.hero_data = data.duplicate(true) as HeroData
	new_hero.initialize_data()
	return new_hero

func _enter_tree() -> void:
	if not GameEvents.combat_event.is_connected(_on_combat_event):
		GameEvents.combat_event.connect(_on_combat_event)


# Triggers unconditionally the exact millisecond the node leaves a slot parent
func _exit_tree() -> void:
	if GameEvents.combat_event.is_connected(_on_combat_event):
		GameEvents.combat_event.disconnect(_on_combat_event)

func _on_combat_event(trigger: Enums.TriggerEvent, context: Dictionary) -> void:
	# Guard: If context contains a slot tracker, verify that it points to THIS hero instance
	if context.has("slot"):
		var slot: HeroSlot = context["slot"]
		if slot and slot.hero != self:
			return # Disregard events belonging to other heroes
	
	# Unpack the optional manager reference cleanly
	var manager: CombatManager = context.get("manager", null)
	
	var combat_context = CombatContext.new(context.get("slot"), [], manager)
	trigger_behavior_event(trigger, combat_context, manager)

func initialize_data() -> void:	
	if hero_data.base_action:
		var action_behavior = Behavior.create(hero_data.base_action)
		action_behavior.owner_hero = self
		add_behavior(action_behavior)
	for ability_res in hero_data.abilities:
		var ability_behavior = Behavior.create(ability_res)
		ability_behavior.owner_hero = self # Inject ownership immediately at creation!
		add_behavior(ability_behavior)
	reset_temporary_data()
	initialize_runtime_stats()

func initialize_runtime_stats() -> void:
	# Assuming Enums.StatType contains MAX_HP, ATTACK, DEFENSE, etc.
	for stat in Enums.StatType.values():
		# Fetch the flat starting values from your immutable resource file
		var base_val = hero_data.get_starting_stat(stat) 
		
		runtime_base_stats[stat] = base_val
		current_stats[stat] = base_val

func prepare_for_combat():
	reset_temporary_data()
	clear_temporary_buffs()

func reset_temporary_data():
	for stat in Enums.StatType.values():
		current_stats[stat] = runtime_base_stats.get(stat, 0)
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

func take_damage(damage : int, source : HeroSlot, manager: CombatManager) -> void:
	var active_max_hp = runtime_base_stats.get(Enums.StatType.HP, hero_data.base_HP)
	## Does this check for behavior increases stats?
	var old_hp = get_stat(Enums.StatType.HP)
	current_stats[Enums.StatType.HP] = clampi(old_hp - damage, 0, active_max_hp)
	
	print(hero_data.name, " takes ", damage, " damage from ", source.hero.hero_data.name if source and source.hero else "unknown")
	var local_slot = manager.hero_to_slot_map.get(self)
	var context = CombatContext.new(local_slot, [], manager)
	trigger_behavior_event(Enums.TriggerEvent.ON_DAMAGE_TAKEN,context,manager)
	GameEvents.hero_damaged.emit(self, source, damage)
	

		
func heal_HP(value : int, source : HeroSlot) -> void:
	var active_max_hp = runtime_base_stats.get(Enums.StatType.HP, hero_data.base_HP)
	var old_hp = get_stat(Enums.StatType.HP)
	current_stats[Enums.StatType.HP] = clampi(old_hp + value, 0, active_max_hp)
	var actual_healed = current_stats[Enums.StatType.HP] - old_hp
	print(hero_data.name, " heals for ", actual_healed)
	#trigger_behavior_event(Enums.TriggerEvent.ON_HEAL,[],manager)
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

	active_passives.append(new_behavior)
		
	return true
		
func remove_behavior(behavior_instance: Behavior) -> void:
	if behavior_instance == null: return
	if behavior_instance.data.type == BehaviorData.BehaviorType.STAT:
		stat_modifiers.erase(behavior_instance)
	else:
		active_passives.erase(behavior_instance)



func trigger_behavior_event(event_type: Enums.TriggerEvent, combat_context: CombatContext, manager: CombatManager) -> void:
	# Fixed Bug 2: Receives the pre-built CombatContext directly, ensuring zero signature parsing conflicts
	for b in active_passives:
		b.route_to_matching_hook(event_type, combat_context, null)

func get_stat(stat_type: Enums.StatType) -> Variant:
	# 2. We check runtime_base_stats first. If missing (for some reason), look inside the defaults dictionary
	var default_fallbacks = {
		Enums.StatType.SPEED: hero_data.base_speed,
		Enums.StatType.RANGE: hero_data.base_range,
		Enums.StatType.DAMAGE: hero_data.base_damage,
		Enums.StatType.HP: hero_data.base_HP,
		Enums.StatType.CRIT: hero_data.base_crit_chance
	}
	var backup_value = default_fallbacks.get(stat_type, 0)
	var final_value = current_stats.get(stat_type, backup_value)
	var stat_wrapper = { "value": final_value }
	for behavior in stat_modifiers:
		if behavior.data.has_method("_execute_stat_modification"):
			behavior.data._execute_stat_modification(stat_wrapper)
	final_value = stat_wrapper["value"]
	
	match stat_type:
		Enums.StatType.DAMAGE, Enums.StatType.SPEED, Enums.StatType.HP:
			return int(maxf(1.0, final_value))
		Enums.StatType.RANGE:
			return int(maxf(0.0, final_value))
		Enums.StatType.CRIT:
			return clampf(final_value, 0.0, 1.0)
	return final_value
	
func get_behaviors() -> Array[Behavior]:
	# Combines both for the UI layer to draw status icons smoothly
	return active_passives + stat_modifiers

func get_enchantments() -> Array[Enchantment]:
	return current_enchantments
	
