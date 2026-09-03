extends CombatEffect
class_name ExchangeHPEffect

# CLEANED: Completely return-free and context-free
func execute(_manager: CombatManager) -> void:
	if target == null or target.hero == null or target.hero.current_HP <= 0:
		return
	if source == null or source.hero == null or source.hero.current_HP <= 0:
		return
		
	# 1. Capture snapshots of the current layout numbers
	var old_target_hp = target.hero.current_HP
	var old_source_hp = source.hero.current_HP
	
	# 2. Swap HP values safely clamped to each hero's specific Max HP limits
	var target_max_hp = target.hero.get_stat(Enums.StatType.MAX_HP)
	target.hero.current_HP = clampi(old_source_hp, 0, target_max_hp)
	
	var source_max_hp = source.hero.get_stat(Enums.StatType.MAX_HP)
	source.hero.current_HP = clampi(old_target_hp, 0, source_max_hp)
	
	# 3. BROADCAST GLOBALLY: Shouts out what just happened so items or trackers can hear it
	GameEvents.hero_damaged.emit(target.hero, source, old_target_hp - target.hero.current_HP)
	GameEvents.hero_healed.emit(source.hero, source, source.hero.current_HP - old_source_hp)

func present(manager: CombatManager) -> void:
	if source and animation != "" and animation != "idle":
		source.play_animation(animation, animation_duration)
		
	if target != null and target.hero != null:
		# CLEANED: Fixed a bug in your original present script where the target's damage effect 
		# was missing an 'await', which would cause animations to instantly overlap!
		target.apply_visual_effect(Enums.EffectType.DAMAGE, is_crit, -1, false)
		await source.apply_visual_effect(Enums.EffectType.HEAL, is_crit, -1).finished
	else:
		await manager.get_tree().process_frame
