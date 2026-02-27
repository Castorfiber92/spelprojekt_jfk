extends Behavior
class_name attack_basic_behavior

func on_execute_action(data):
	# Calculate Damage
	# We start with base damage and let other behaviors (like 'Strength' or 'Weakness') modify it
	var targets = data as Array[Hero]
	for i in targets:
		var damage = owner_hero.current_damage
		var final_damage = owner_hero.apply_value_modifier("on_calculate_damage", int(damage))
		# Apply the Attack
		# This triggers 'on_damage_taken' inside the target hero
		i.take_damage(final_damage, owner_hero)
	
		# Visual Feedback
		print(owner_hero.hero_data.name, " attacks ", i.hero_data.name, " for ", final_damage)
