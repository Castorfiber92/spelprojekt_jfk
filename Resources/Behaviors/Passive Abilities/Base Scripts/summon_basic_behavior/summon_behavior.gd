extends BehaviorData
class_name SummonBehavior

@export_group("Summon Settings")
@export var hero_to_summon : HeroData

func on_death(combatContext: CombatContext, executor: Behavior, attack_history: Variant = null) -> void:
	print("ANYBODY HERE?")
	if hero_to_summon == null: return
	
	var runtime_owner = executor.owner_hero
	var caster_slot = combatContext.source 
	
	# This commands the SummonEffect to safely occupy the exact grid slot left behind by the death.
	var effect = executor.create_effect(SummonEffect, caster_slot, caster_slot) as SummonEffect
	
	if effect:
		effect.hero_to_summon = hero_to_summon
		
		# Caches the team assignment smoothly from the snapshot
		if runtime_owner:
			effect.cached_team = runtime_owner.team
		else:
			# Fallback if slot tracking is already clearing
			effect.cached_team = caster_slot.team
			
		GameEvents.effect_created.emit(effect)
