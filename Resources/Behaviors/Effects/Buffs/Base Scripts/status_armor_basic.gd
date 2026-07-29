extends BehaviorData
class_name Status_ArmorBehavior

func modify_incoming_effect(effect : CombatEffect, executor: Behavior):
	# Reduce stacks accordingly to damage, only if it is a damaging effect
	if effect is DamageEffect and executor.current_stacks > 0:
		var damage_blocked = mini(effect.value, executor.current_stacks)
		# Reduce the incoming damage value
		effect.value = maxi(0, effect.value - damage_blocked)
		executor.current_stacks -= damage_blocked
		print(executor.owner_hero.hero_data.name, " blocked ", damage_blocked, " damage. Armor stacks left: ", executor.current_stacks)
	if executor.current_stacks <= 0:
		executor.owner_hero.remove_behavior(executor)
