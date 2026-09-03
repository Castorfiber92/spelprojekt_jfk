extends CombatEffect
class_name ExchangeHPEffect
var context : CombatContext
func execute(_manager) -> CombatContext:
	#context = CombatContext.new(source, [target], _manager)

	if target == null or target.hero == null or target.hero.current_HP <= 0:
		return
	if source == null or source.hero == null or source.hero.current_HP <= 0:
		return
		
	# 1. Capture the target's current health before modifying anything
	var old_target_hp = target.hero.current_HP
	var old_source_hp = source.hero.current_HP
	var stolen_hp = target.hero.current_HP
	
	# 2. swap hp to the source's hp
	var target_max_hp = target.hero.get_stat(Enums.StatType.MAX_HP)
	target.hero.current_HP = clampi(old_source_hp, 0, target_max_hp)
	
	# 3. set the source's hp
	var source_max_hp = source.hero.get_stat(Enums.StatType.MAX_HP)
	source.hero.current_HP = clampi(stolen_hp, 0, source_max_hp)
	
	return

func present(manager: CombatManager):
		# 1. Source plays animation
	if source and animation != "" and animation != "idle":
		source.play_animation(animation, animation_duration)
		
	# 2. TARGET REACTS SECOND, if they should from a buff?
	if target != null:
			target.apply_visual_effect(Enums.EffectType.DAMAGE, is_crit, -1, false).finished
			await source.apply_visual_effect(Enums.EffectType.HEAL,is_crit, -1).finished
	else:
		# Fallback delay so the coroutine loop doesn't snap if the target is missing
		await manager.get_tree().process_frame
