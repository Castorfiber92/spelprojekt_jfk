extends Behavior
class_name on_death_basic_behavior

func on_death(combatContext : CombatContext):
	var effect = create_effect(SummonEffect, null, combatContext.source.hero) as SummonEffect
	effect.hero_to_summon = hero_to_summon
	GameEvents.effect_created.emit(effect)
