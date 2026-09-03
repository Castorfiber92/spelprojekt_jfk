extends BehaviorData
class_name status_stun_basic_behavior

func on_turn_start(combatContext: CombatContext, executor: Behavior, attack_history: Variant = null) -> void:
	executor.current_stacks -= 1
	if executor.current_stacks <= 0:
		executor.owner_hero.remove_behavior(executor)
