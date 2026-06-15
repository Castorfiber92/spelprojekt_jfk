extends Behavior
class_name bash_base

@export var damage_multiplier: float = 2
@export var chance: float = 0.25

func modify_outgoing_effect(effect : CombatEffect):
	if randf() < chance:
		effect.value = effect.value * damage_multiplier
		effect.buffs.append(effect)
		print ("Effect " + name + " triggered!")
