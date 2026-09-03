extends CombatEffect
class_name SummonEffect

var hero_to_summon : HeroData
var cached_team : Enums.Team 

func execute(_manager: CombatManager) -> void:
	if hero_to_summon == null or source == null:
		print("SummonEffect fizzled: Corrupted metadata.")
		return
		
	if source.hero != null:
		print("SummonEffect fizzled: Target slot ", source.name, " is occupied!")
		return
		
	# Spawn the minion and securely assign it directly to the designated empty slot layout
	_manager.spawn_and_assign_hero(hero_to_summon, source, cached_team)
	print("Summon Success: Reoccupied slot ", source.name, " with: ", hero_to_summon.name)

func present(manager: CombatManager) -> void:
	# Keep your fallback frame hold so the asynchronous timeline sequence stays fluid
	await manager.get_tree().process_frame
