extends Behavior
class_name heal_basic_behavior

func on_execute_action(combatContext : CombatContext):
	for target in combatContext.targets:
		if target.hero == null: continue
		var target_hero = target.hero
		# 1. Create the "Draft" CombatEffect
		# We set the base damage here.
		var effect = CombatEffect.new(
			owner_hero, 
			target_hero, 
			"HEAL", 
			owner_hero.current_damage)
		
		# 2. Add tags so other items know what this is
		# effect.tags.append("basic_attack")
		# effect.tags.append("melee") # or "ranged" based on your hero

		GameEvents.effect_created.emit(effect)
		print(owner_hero.hero_data.name, " used ", name, " on ", target_hero.hero_data.name)
