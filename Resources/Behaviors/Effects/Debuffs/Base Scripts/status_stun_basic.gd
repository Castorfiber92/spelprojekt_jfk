extends Behavior
class_name status_stun_basic_behavior

func on_turn_start(combatContext : CombatContext):
	duration -= 1

func on_turn_end(combatContext : CombatContext):
	if duration <= 0:
		combatContext.source.hero.remove_behavior(name)
