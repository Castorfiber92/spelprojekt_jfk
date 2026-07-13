extends Behavior
class_name mark_behavior

func modify_outgoing_effect(effect : CombatEffect):
	if not effect is DamageEffect:
		return
	if effect.target.team == effect.source.team:
		return 
	for b in behaviors_to_apply:
		effect.buffs.append(b.duplicate())
		print ("Effect " + name + " triggered!")
