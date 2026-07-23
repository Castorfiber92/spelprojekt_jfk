extends Behavior
class_name status_poison_basic_behavior

func on_turn_end(combatContext: CombatContext):
	for target in combatContext.targets:
		var effect = create_effect(DamageEffect, target.hero, combatContext.source.hero)
		effect.value = stacks 
		GameEvents.effect_created.emit(effect)
		
	# Tick down and clean up
	stacks -= 1
	if stacks <= 0:
		combatContext.source.hero.remove_behavior(name)
