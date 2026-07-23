extends Behavior
class_name attack_basic_behavior

func on_execute_action(combatContext : CombatContext):
	for target in combatContext.targets:
		var effect = create_effect(DamageEffect, target.hero, combatContext.source.hero)
		effect.value = combatContext.source.hero.current_damage
		GameEvents.effect_created.emit(effect)
