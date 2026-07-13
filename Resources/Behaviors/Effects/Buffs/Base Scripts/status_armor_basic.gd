extends Behavior
class_name status_armor_basic_behavior

func modify_incoming_effect(effect : CombatEffect):
	# Reduce stacks accordingly to damage, only if it is a damaging effect
	if effect is DamageEffect and stacks > 0:
		var damage_blocked = mini(effect.value, stacks)
		# Reduce the incoming damage value
		effect.value = maxi(0, effect.value - damage_blocked)
		stacks -= damage_blocked
		print(owner_hero.hero_data.name, " blocked ", damage_blocked, " damage. Armor stacks left: ", stacks)

func on_damage_taken(combatContext : CombatContext):
	# Check after taking damage if the stacks of armor is 0, then remove the behavior.
	print (str(combatContext.source.hero))
	if stacks <= 0:
		owner_hero.remove_behavior(name)
