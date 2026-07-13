extends Behavior
class_name bonus_damage_behavior

@export var bonus_damage : int

func modify_outgoing_effect(effect: CombatEffect):
	# We check if the "Draft" created by the attack has the right tag
	# We use your variable here instead of a hardcoded number
	effect.value += bonus_damage 
	print("Bonus Damage applied: +", bonus_damage, " (Total: ", effect.value, ")")
