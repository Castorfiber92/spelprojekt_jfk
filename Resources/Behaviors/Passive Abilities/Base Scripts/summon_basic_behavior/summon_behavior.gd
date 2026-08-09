extends BehaviorData
class_name SummonBehavior

@export_group("Summon Settings")
@export var hero_to_summon : HeroData

func _execute_behavior_payload_override(context: CombatContext, executor: Behavior, attack_history: Variant = null):
	if hero_to_summon == null: return
	
	var runtime_owner = executor.owner_hero
	# Your stack processor passes the death slot straight out as context.source!
	var caster_slot = context.source 
	
	# Instantiate the effect wrapper using the death slot as the source anchor
	var effect = executor.create_effect(SummonEffect, null, runtime_owner, caster_slot) as SummonEffect
	
	if effect:
		effect.hero_to_summon = hero_to_summon
		
		# SAFEGUARD: Cache the team alignment from the snapshot before it is wiped!
		if runtime_owner:
			effect.cached_team = runtime_owner.team
		else:
			# Fallback fallback layout mapping check
			effect.cached_team = caster_slot.team
			
		GameEvents.effect_created.emit(effect)
