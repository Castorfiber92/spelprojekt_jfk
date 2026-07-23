extends Behavior
class_name cast_basic_behavior

func on_execute_action(combatContext : CombatContext):
	for target in combatContext.targets:
		var effect = create_effect(CastEffect, target.hero, combatContext.source.hero)
		GameEvents.effect_created.emit(effect)
