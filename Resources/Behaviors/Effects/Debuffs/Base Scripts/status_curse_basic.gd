extends BehaviorData

class_name status_curse_basic_behavior

func _execute_behavior_payload_override(combat_context: CombatContext, executor: Behavior, attack_history: Variant = null):
	var effect = executor.create_effect(BuffEffect, combat_context.source, executor.owner_hero, combat_context.source) as BuffEffect
	GameEvents.effect_created.emit(effect)

#Maybe this should be a general apply buff kind of effect? Its all variables after all, it doesn need to
#be a specific curse thing, i think
