extends BehaviorData
class_name status_stun_basic_behavior

func _execute_behavior_payload_override(combat_context: CombatContext, executor: Behavior, attack_history: Variant = null):
	# Tick down the live tracking stacks counter on our runtime instance
	executor.current_stacks -= 1
	# If stun wears off, use your object-based deferred removal system to erase it
	if executor.current_stacks <= 0:
		executor.owner_hero.remove_behavior(executor)
