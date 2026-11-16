extends BehaviorData

class_name status_curse_basic_behavior

func on_round_end(combatContext: CombatContext, executor: Behavior, attack_history: Variant = null) -> void:
	var effect = executor.create_effect(BuffEffect, combatContext.source, combatContext.source) as BuffEffect
	effect.origin = CombatEffect.EffectOrigin.STATUS_TICK
	GameEvents.effect_created.emit(effect)
