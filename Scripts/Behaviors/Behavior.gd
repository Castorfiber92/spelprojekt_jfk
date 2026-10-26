extends RefCounted
class_name Behavior

var data: BehaviorData # Holds our configuration parameters safely
var owner_hero: Hero   # Unique runtime owner, completely safe from overwrites!
var current_stacks: int
var status_type: Enums.StatusType

static func create(_data : BehaviorData) -> Behavior:
	var instance = Behavior.new()
	var duplicated_data = _data.duplicate(true)
	var sterile_array: Array[BehaviorData] = []
	for nested_res in duplicated_data.behaviors_to_apply:
		if nested_res != null:
			# Explicitly clone the sub-resources so they can never share memory blocks
			sterile_array.append(nested_res.duplicate(true))
	duplicated_data.behaviors_to_apply = sterile_array
	instance.data = duplicated_data
	instance.current_stacks = _data.base_stacks
	return instance

# --- CLEANED DIRECT PASS-THROUGH HOOKS ---
func route_to_matching_hook(event_type: Enums.TriggerEvent, context: CombatContext, history: Variant) -> void:
	match event_type:
		# FIXED: Calls the local pass-through hook on 'self', which cleanly passes 
		# the context, the runtime instance, and the history down to your scripts!
		Enums.TriggerEvent.ON_EXECUTE_ACTION: on_execute_action(context, history)
		Enums.TriggerEvent.ON_START_OF_BATTLE: on_start_of_battle(context, history)
		Enums.TriggerEvent.ON_TURN_START: on_turn_start(context, history)
		Enums.TriggerEvent.ON_TURN_END: on_turn_end(context, history)
		Enums.TriggerEvent.ON_ATTACK: on_attack(context, history)
		Enums.TriggerEvent.ON_DAMAGE_DEALT: on_damage_dealt(context, history)
		Enums.TriggerEvent.ON_DAMAGE_TAKEN: on_damage_taken(context, history)
		Enums.TriggerEvent.ON_DEATH: on_death(context, history)
		Enums.TriggerEvent.ON_ROUND_END: on_round_end(context, history)

# ==============================================================================
# Direct Pass-Through Event Hooks
# ==============================================================================
func on_execute_action(context: CombatContext, history: Variant = null) -> void: 
	if data.has_method("on_execute_action"): data.on_execute_action(context, self, history)

func on_start_of_battle(context: CombatContext, history: Variant = null) -> void: 
	if data.has_method("on_start_of_battle"): data.on_start_of_battle(context, self, history)

func on_turn_start(context: CombatContext, history: Variant = null) -> void:     
	if data.has_method("on_turn_start"): data.on_turn_start(context, self, history)

func on_turn_end(context: CombatContext, history: Variant = null) -> void:       
	if data.has_method("on_turn_end"): data.on_turn_end(context, self, history)

func on_attack(context: CombatContext, history: Variant = null) -> void:         
	if data.has_method("on_attack"): data.on_attack(context, self, history)

func on_damage_dealt(context: CombatContext, history: Variant = null) -> void:   
	if data.has_method("on_damage_dealt"): data.on_damage_dealt(context, self, history)

func on_damage_taken(context: CombatContext, history: Variant = null) -> void:   
	if data.has_method("on_damage_taken"): data.on_damage_taken(context, self, history)

func on_death(context: CombatContext, history: Variant = null) -> void:          
	if data.has_method("on_death"): data.on_death(context, self, history)

func on_round_end(context: CombatContext, history: Variant = null) -> void:      
	if data.has_method("on_round_end"): data.on_round_end(context, self, history)


func modify_outgoing_effect(effect : CombatEffect):
# Path A: Gated flow. If the resource implements 'modify_outgoing_effect', 
	# it wants to run through the trigger gates first.
	if data.has_method("modify_outgoing_effect"):
		## If the modifying behavior should trigger on the hero crit and the crit hasn't triggered, return
		if data.trigger_on_innate_crit and not effect.is_crit:
			return
		## If the proc chance of the modifying behavior fails, return
		if data.proc_chance < 1.0 and randf() > data.proc_chance:
			return
		## If the modifying behavior forces the action to become a crit, set it as crit
		effect.is_crit = data.force_critical_strike
		
		# Pass the call to the resource, providing 'self' as the runtime executor state
		data.modify_outgoing_effect(effect, self)
		
	# Path B: Direct execution override (Like InfuseBuffsModifier)
	elif data.has_method("_execute_outgoing_modification"):
		data._execute_outgoing_modification(effect)

func _execute_outgoing_modification(effect: CombatEffect):
	if data.has_method("_execute_outgoing_modification"):
		data._execute_outgoing_modification(effect)
	
func modify_incoming_effect(effect : CombatEffect):
	# If your custom status resource script implements 'modify_incoming_effect'
	if data.has_method("modify_incoming_effect"):
		# In this case, your status mark script doesn't have gates, so we call it directly,
		# passing 'self' so your script can read live variables like 'current_stacks'!
		data.modify_incoming_effect(effect, self)
		
	# Fallback if you ever create an incoming modifier that needs to bypass everything
	elif data.has_method("_execute_incoming_modification"):
		data._execute_incoming_modification(effect, self)
		
func _execute_incoming_modification(effect: CombatEffect):
	if data.has_method("_execute_incoming_modification"):
		data._execute_incoming_modification(effect, self)
		
# Called on the ATTACKER to modify the raw pool of enemies before range math
func modify_initial_targets(active_candidates: Array[HeroSlot], source: HeroSlot) -> Array[HeroSlot]:
	if data.has_method("modify_initial_targets"):
		return data.modify_initial_targets(active_candidates, source, self)
	return active_candidates

# Called on the DEFENDER to let them alter the pool (e.g., Taunt forcing itself to be targeted)
func modify_defender_final_targets(reachables: Array[HeroSlot], defender_slot: HeroSlot) -> Array[HeroSlot]:
	if data.has_method("modify_defender_final_targets"):
		return data.modify_defender_final_targets(reachables, defender_slot, self)
	return reachables

# Called on the ATTACKER at the very end to scale targets up or down (Cleave, AOE, Snipe)
func modify_attacker_final_targets(resolved_targets: Array[HeroSlot], reachable_pool: Array[HeroSlot]) -> Array[HeroSlot]:
	if data.has_method("modify_attacker_final_targets"):
		return data.modify_attacker_final_targets(resolved_targets, reachable_pool, self)
	return resolved_targets

#Universal Validation Gate
func _check_trigger(current_hook: String, context: CombatContext, trigger_data: Variant):
	var expected_hook_string = Enums.TRIGGER_STRINGS.get(data.trigger_event, "")
	# If it is the current triggering event/combat phase
	if current_hook != expected_hook_string:
		return 
		
	# Execute the payload
	_execute_behavior_payload(context,trigger_data)

func _execute_behavior_payload(context: CombatContext,trigger_data):
	# If the linked data resource asset contains a custom execution payload override, we call it
	if data.has_method("_execute_behavior_payload_override"):
		data._execute_behavior_payload_override(context, self, trigger_data)

func roll_crit_local(checking_hero: Hero, main_action_crit: bool = false) -> bool:
	if data.force_critical_strike: 
		return true
	# Main independent proc chance check
	if data.proc_chance < 1.0 and randf() > data.proc_chance: 
		return false
	# Determine if a critical strike is actually occurring
	var rolled_innate: bool = randf() < checking_hero.get_stat(Enums.StatType.CRIT)
	# Not sure if this is as it should be here, but it works as long as we set the basic action behaviors
	# to trigger_on_innate = true
	var critical_to_check: bool = main_action_crit if main_action_crit != false else rolled_innate
	# If the effect REQUIRES a crit to trigger, return the crit status
	if data.trigger_on_innate_crit: 
		return critical_to_check
	return critical_to_check if data.proc_chance == 1.0 else true

func create_effect(effect_type: Script, target_slot: HeroSlot, source_slot: HeroSlot) -> CombatEffect:
	var effect = effect_type.new() as CombatEffect
	effect.source = source_slot
	effect.target = target_slot
	effect.effect_owner = owner_hero 
	effect.animation = data.animation
	effect.animation_duration = data.animation_duration
	
	for data_template in data.behaviors_to_apply:
		if data_template != null:
			effect.buffs.append(Behavior.create(data_template))
			
	return effect
