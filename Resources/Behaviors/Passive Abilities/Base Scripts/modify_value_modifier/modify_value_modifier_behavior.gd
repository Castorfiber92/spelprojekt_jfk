extends BehaviorData
class_name ModifyValueModifier
@export_group("Target Filtering")
## Select what type of outgoing effect this modifier is allowed to touch
# This is if an ability should lower an effect by x amount, use the modify_stat_modifier if you
# want to give a stat increase/decrease to raw stats of a hero
@export var modified_effect_type: Enums.EffectType = Enums.EffectType.DAMAGE
# Keep in mind this currently ONLY works for outgoing effects, so think damage, range, etc.
@export_group("Value Modification Settings")
## The flat amount to add or subtract (use negative numbers for reductions/debuffs)
@export var flat_value_modifier : int = 0

func _execute_outgoing_modification(effect: CombatEffect,is_behavior_crit : bool):
	match modified_effect_type:
		Enums.EffectType.DAMAGE:
			if not (effect is DamageEffect): return
		Enums.EffectType.HEAL:
			if not (effect is HealEffect): return
	# Pure mathematical mutation:
	# Works on DamageEffects (Bonus Damage), HealEffects (Bonus Healing), or possibly ShieldEffects
	effect.value += flat_value_modifier
