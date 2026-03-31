extends Behavior
class_name attack_basic_behavior

func on_execute_action(data):
	var targets = data as Array[Hero]
	for target in targets:
		# 1. Create the "Draft" CombatEffect
		# We set the base damage here.
		var effect = CombatEffect.new(
			owner_hero, 
			target, 
			"DAMAGE", 
			owner_hero.current_damage)
		
		# 2. Add tags so other items know what this is
		# effect.tags.append("basic_attack")
		# effect.tags.append("melee") # or "ranged" based on your hero

		GameEvents.effect_created.emit(effect)
		print(owner_hero.hero_data.name, " used ", name, " on ", target.hero_data.name)
