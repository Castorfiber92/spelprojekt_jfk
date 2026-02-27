extends Behavior
class_name bonus_damage_behavior

@export var bonus_damage : int

func on_calculate_damage(data):
	var new_total = data + bonus_damage
	print("Bonus Damage applied: +", bonus_damage, " (Total: ", new_total, ")")
	return new_total
