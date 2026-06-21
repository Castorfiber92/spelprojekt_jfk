extends Behavior
class_name status_stun_basic_behavior

func on_turn_start(combatContext : CombatContext):
	stacks -= 1

func on_turn_end(combatContext : CombatContext):
	if stacks <= 0:
		combatContext.source.hero.remove_behavior(name)
