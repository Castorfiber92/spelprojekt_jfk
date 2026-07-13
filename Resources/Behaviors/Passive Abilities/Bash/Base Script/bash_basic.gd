extends Behavior
class_name bash_basic_behavior

@export var damage_multiplier: float = 2
@export var chance: float = 0.15

func modify_outgoing_effect(effect : CombatEffect):
	if not effect is DamageEffect:
		return
	if effect.target.team == effect.source.team:
		return 
	if randf() < chance:
		effect.is_crit = true
		effect.value = effect.value * damage_multiplier
		for b in behaviors_to_apply:
			effect.buffs.append(b.duplicate())
		print ("Effect " + name + " triggered!")
