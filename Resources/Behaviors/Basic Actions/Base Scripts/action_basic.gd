extends BehaviorData
class_name BasicActionBehavior

enum ActionType { ATTACK, CAST }
@export var action_profile: ActionType = ActionType.ATTACK
	
func on_execute_action(combatContext: CombatContext, executor: Behavior, attack_history: Variant = null) -> void:
	var source_slot = combatContext.source
	if source_slot == null or source_slot.hero == null: return
	
	var rolled_a_crit: bool = executor.roll_crit_local(source_slot.hero)
	var runtime_owner = executor.owner_hero
	
	for target in combatContext.targets:
		match action_profile:
			ActionType.ATTACK:
				var effect = executor.create_effect(DamageEffect, target, source_slot) as DamageEffect
				effect.is_crit = rolled_a_crit
				
				var final_damage = source_slot.hero.get_stat(Enums.StatType.DAMAGE)
				if rolled_a_crit:
					final_damage = int(final_damage * crit_multiplier)
				
				effect.value = final_damage
				check_enchantment_effects(runtime_owner, effect)
				GameEvents.effect_created.emit(effect)
				
			ActionType.CAST:
				var effect = executor.create_effect(BuffEffect, target, source_slot) as BuffEffect
				effect.is_crit = rolled_a_crit

				for b in effect.buffs:
					if rolled_a_crit and crit_multiplier > 1.0:
						b.current_stacks = int(b.current_stacks * crit_multiplier)

				
				GameEvents.effect_created.emit(effect)

func check_enchantment_effects(behavior_owner: Hero, effect: CombatEffect) -> void:
	# Step A: Apply inherent behavior tags first
	if status_type != 0:
		effect.add_or_stack_status(status_type, base_stacks)
	
	# Step B: Loop through dynamic hero enchantments and stack them on top
	var hero_enchantments = get_enchantments(behavior_owner)
	for e in hero_enchantments:
		# Maps the enchantment type to the combat status type, then stacks it
		var base_data = Maps.get_status_from_type(e.enchantment_type)
		var behavior_runtime = Behavior.create(base_data)
		effect.add_or_stack_status(behavior_runtime, e.stacks)

func get_enchantments(behavior_owner: Hero) -> Array[Enchantment]:
	var enchantments: Array[Enchantment] = []
	for e in behavior_owner.current_enchantments:
		enchantments.append(e) # Safe if status instantiation handles the final runtime data
	return enchantments
