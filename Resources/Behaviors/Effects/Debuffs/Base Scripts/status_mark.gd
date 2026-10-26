extends BehaviorData
class_name status_mark_basic_behavior
# Right now this increases ALL damageeffects - including status such as poison, burn etc.
func modify_incoming_effect(effect : CombatEffect, executor: Behavior):
	# Due to this structure
	if effect is DamageEffect:
		effect.value = effect.value + 1
		#effect.is_crit = true
