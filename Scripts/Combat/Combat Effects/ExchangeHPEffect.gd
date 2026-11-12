extends CombatEffect
class_name ExchangeHPEffect

func execute(_manager: CombatManager) -> void:
	if target == null or target.hero == null or target.hero.get_current_stat(Enums.StatType.HP) <= 0:
		return
	if source == null or source.hero == null or source.hero.get_current_stat(Enums.StatType.HP) <= 0:
		return

	# 1. Capture snapshots of the current layout numbers
	var old_target_hp = target.hero.get_current_stat(Enums.StatType.HP)
	print("target name " + str(target.hero.hero_data.name))
	var old_source_hp = source.hero.get_current_stat(Enums.StatType.HP)
	print("Source name "+ str(source.hero.hero_data.name))
	
	# 2. Swap HP values safely clamped to each hero's specific Max HP limits
	var target_max_hp = target.hero.get_base_stat(Enums.StatType.HP)
	target.hero.current_stats[Enums.StatType.HP] = clampi(old_source_hp, 0, target_max_hp)
	
	var source_max_hp = source.hero.get_base_stat(Enums.StatType.HP)
	source.hero.current_stats[Enums.StatType.HP] = clampi(old_target_hp, 0, source_max_hp)
	
	# 3. BROADCAST GLOBALLY: Shouts out what just happened so items or trackers can hear it
	var target_delta = old_target_hp - target.hero.get_current_stat(Enums.StatType.HP)
	var source_delta = old_source_hp - source.hero.get_current_stat(Enums.StatType.HP)
	
	# 5. BROADCAST GLOBALLY: Fire signals based on whether they took damage or gained healing
	if target_delta > 0:
		GameEvents.hero_damaged.emit(target.hero, source, target_delta)
	elif target_delta < 0:
		GameEvents.hero_healed.emit(target.hero, source, abs(target_delta))
		
	if source_delta > 0:
		GameEvents.hero_damaged.emit(source.hero, source, source_delta)
	elif source_delta < 0:
		GameEvents.hero_healed.emit(source.hero, source, abs(source_delta))

func present(manager: CombatManager) -> void:
	if source and animation != "" and animation != "idle":
		source.play_animation(animation, animation_duration)
		
	if target != null and target.hero != null:
		target.apply_visual_effect(Enums.EffectType.DAMAGE, is_crit, -1, false)
		await source.apply_visual_effect(Enums.EffectType.HEAL, is_crit, -1).finished
	else:
		await manager.get_tree().process_frame
