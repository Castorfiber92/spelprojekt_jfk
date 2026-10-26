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
				var effect = executor.create_effect(DamageEffect, target, source_slot)
				effect.is_crit = rolled_a_crit
				
				var final_damage = source_slot.hero.get_stat(Enums.StatType.DAMAGE)
				if effect.is_crit:
					final_damage = int(final_damage * crit_multiplier)
				
				effect.value = final_damage
				check_enchantment_effects(runtime_owner, effect)
				GameEvents.effect_created.emit(effect)
				
			ActionType.CAST:
				var effect = executor.create_effect(BuffEffect, target, source_slot)
				effect.is_crit = rolled_a_crit

				for b in effect.buffs:
					if rolled_a_crit and crit_multiplier > 1.0:
						b.current_stacks = int(b.current_stacks * crit_multiplier)
				check_enchantment_effects(runtime_owner, effect)
				GameEvents.effect_created.emit(effect)

## THIS IS THE CUSTOMIZEABLE ENCHANTMENT FUNCTION, FOR ATTACKS AND CASTS THIS IS THE FUNCTIONALITY
## BUT FOR OTHER BASIC ACTIONS THAT SHOULD HAVE CUSTOM FUNCTIONALITY WE NEED TO DEFINE THIS IN THOSE
## SCRIPTS AS WELL OR ENCHANTS WON'T DO ANYTHING
# Currently, this simply checks first if the behavior itself has an inherent enchantment, such as fire arrows of
# troll ranger, makes sure the combateffect applies the correct status and then checks the enchantments of the
# hero itself, and then applies stacks (if the enchantment is the same) or adds the correct status+stacks of
# the hero enchant, such as poison, freeze, etc.
func check_enchantment_effects(behavior_owner: Hero, effect: CombatEffect) -> void:
	# Step A: Apply inherent behavior tags first
	if status_type != 0:
		var inherent_stacks = base_stacks * 2 if effect.is_crit else base_stacks
		effect.add_or_stack_status(status_type, inherent_stacks)
	# Step B: Loop through dynamic hero enchantments and stack them on top
	for e in behavior_owner.get_enchantments():
		var base_data = Maps.get_status_from_type(e.enchantment_type)
		var behavior_runtime = Behavior.create(base_data)
		var enchant_stacks = e.stacks * 2 if effect.is_crit else e.stacks
		effect.add_or_stack_status(behavior_runtime, enchant_stacks)
