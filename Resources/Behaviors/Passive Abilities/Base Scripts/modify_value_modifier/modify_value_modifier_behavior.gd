extends BehaviorData
class_name ModifyValueModifier

# Keep in mind this currently ONLY works for outgoing effects, so think damage, range, etc.
@export_group("Value Modification Settings")
## The flat amount to add or subtract (use negative numbers for reductions/debuffs)
@export var flat_value_modifier : int = 0
@export var static_value_modifier : int = -1

func _execute_outgoing_modification(effect: CombatEffect,is_behavior_crit : bool):
	if static_value_modifier != -1:
		effect.value = static_value_modifier
		return
	# Pure mathematical mutation:
	# Works on DamageEffects (Bonus Damage), HealEffects (Bonus Healing), or ShieldEffects
	effect.value += flat_value_modifier
