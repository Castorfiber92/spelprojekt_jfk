extends Behavior
class_name bash_basic_behavior

@export var damage_multiplier: float = 2
@export var chance: float = 1

func modify_outgoing_effect(effect : CombatEffect):
	if randf() < chance:
		effect.value = effect.value * damage_multiplier
		for b in behaviors_to_apply:
			effect.buffs.append(b.duplicate())
		print ("Effect " + name + " triggered!")
