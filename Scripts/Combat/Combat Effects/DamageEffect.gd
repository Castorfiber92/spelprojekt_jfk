extends CombatEffect
class_name DamageEffect

# For actions that deal damage as base
func execute(_manager: CombatManager) -> void:
	if target and target.hero != null:
		# The target hero mutates its numbers and emits GameEvents.hero_damaged natively
		target.hero.take_damage(int(value), source)
		
		# Inject item status buffs attached to this attack profile cleanly
		for b in buffs:
			target.hero.add_behavior(b)

func present(manager: CombatManager) -> void:
	# 1. Attacker visual animation pose fires first
	if source and animation != "" and animation != "idle":
		source.play_animation(animation, animation_duration)
		
	# 2. Target slot shakes and pops floating text labels
	if target:
		# Simply pass the raw calculated values straight into your existing tween engine!
		await target.apply_visual_effect(Enums.EffectType.DAMAGE, is_crit, int(value)).finished
	else:
		await manager.get_tree().process_frame
