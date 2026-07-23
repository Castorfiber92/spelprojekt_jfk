extends Behavior
class_name armor_basic_behavior

func on_turn_start(combatContext : CombatContext):
	for target in combatContext.targets:
		var effect = create_effect(CastEffect, target.hero, combatContext.source.hero)
		effect.animation = ""
		GameEvents.effect_created.emit(effect)
