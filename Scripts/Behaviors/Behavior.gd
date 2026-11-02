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

func route_to_matching_hook(event_type: Enums.TriggerEvent, context: CombatContext, history: Variant) -> void:
	# If this is an action phase and targets haven't been resolved yet, solve them!
	if event_type == Enums.TriggerEvent.ON_EXECUTE_ACTION and context.targets.is_empty():
		context.targets = TargetingSolver.resolve_targets(self, context.source, context.manager)

	var method_name: String = Enums.TRIGGER_STRINGS.get(event_type, "")
	if method_name != "" and data.has_method(method_name):
		data.call(method_name, context, self, history)

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

func modify_incoming_effect(effect : CombatEffect):
	# If your custom status resource script implements 'modify_incoming_effect'
	if data.has_method("modify_incoming_effect"):
		# In this case, your status mark script doesn't have gates, so we call it directly,
		# passing 'self' so your script can read live variables like 'current_stacks'!
		data.modify_incoming_effect(effect, self)
	# Fallback if you ever create an incoming modifier that needs to bypass everything
	elif data.has_method("_execute_incoming_modification"):
		data._execute_incoming_modification(effect, self)
	
func modify_targets(method_name: String, target_pool: Array[HeroSlot], context_slot: HeroSlot, extra_pool: Variant = null) -> Array[HeroSlot]:
	if data.has_method(method_name):
		# If it's modify_attacker_final_targets, it takes (resolved, reachable, self)
		# Called on the ATTACKER at the very end to scale targets up or down (Cleave, AOE, Snipe)
		if extra_pool != null:
			return data.call(method_name, target_pool, extra_pool, self)
		# Otherwise, it takes (candidates/reachables, source/defender_slot, self)
		# Called on the ATTACKER to modify the raw pool of enemies before range math
		# OR Called on the DEFENDER to let them alter the pool (e.g., Taunt forcing itself to be targeted)
		return data.call(method_name, target_pool, context_slot, self)
	return target_pool

#Universal Validation Gate
func _check_trigger(current_hook: String, context: CombatContext, trigger_data: Variant) -> void:
	if current_hook == Enums.TRIGGER_STRINGS.get(data.trigger_event, ""):
		_execute_behavior_payload(context, trigger_data)

func _execute_behavior_payload(context: CombatContext, trigger_data: Variant) -> void:
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
