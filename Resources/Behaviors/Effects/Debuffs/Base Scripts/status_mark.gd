extends Behavior
class_name status_mark_basic_behavior

func modify_incoming_effect(effect : CombatEffect):
	if effect is DamageEffect:
		effect.value = effect.value + 1
		var damage_blocked = mini(effect.value, stacks)
		effect.is_crit = true
