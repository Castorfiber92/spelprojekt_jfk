extends Behavior
class_name attack_basic_behavior
@export var animation : String = "action"
@export var animationDuration : float = 0.15

func on_execute_action(context : CombatContext):
	for target in context.targets:
		# Instantiate the specific configuration subclass
		var effect = DamageEffect.new() 
		
		effect.value = get_modified_stat(context.source.hero, "damage", context.source.hero.current_damage)
		effect.source = context.source.hero
		effect.target = target.hero
		effect.animation = self.animation
		effect.animation_duration = self.animationDuration
		
		# Emit to the CombatManager queue safely
		GameEvents.effect_created.emit(effect)

	
