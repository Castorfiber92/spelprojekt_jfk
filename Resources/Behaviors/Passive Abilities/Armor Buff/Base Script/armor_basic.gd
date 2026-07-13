extends Behavior
class_name armor_basic_behavior

func on_turn_start(combatContext : CombatContext):
	
	var actual_targets = combatContext.targets
	
	# If targets are empty (e.g. pre-turn phase), use our unified layout rules
	if actual_targets.is_empty():
		actual_targets = combatContext.resolve_targets(self, combatContext.manager)
		
	for target in combatContext.targets:
		# Instantiate the specific configuration subclass
		var effect = CastEffect.new() 
		effect.buffs = behaviors_to_apply
		effect.source = combatContext.source.hero
		effect.target = target.hero
		#effect.animation = ""
		#effect.animation_duration = self.animationDuration
		# Emit to the CombatManager queue safely
		GameEvents.effect_created.emit(effect)
