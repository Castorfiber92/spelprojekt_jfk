extends Behavior
class_name attack_basic_behavior
@export var animation : String = "action"
@export var animationDuration : float = 0.15

func on_execute_action(combatContext : CombatContext):
	for target in combatContext.targets:
		# Instantiate the specific configuration subclass
		var effect = DamageEffect.new() 
		
		effect.value = get_modified_stat(combatContext.source.hero, "damage", combatContext.source.hero.current_damage)
		effect.source = combatContext.source.hero
		effect.target = target.hero
		effect.animation = self.animation
		effect.animation_duration = self.animationDuration
		# Emit to the CombatManager queue safely
		GameEvents.effect_created.emit(effect)

	
