extends Resource
class_name HeroGrowthData

@export_category("Stat Growth Profiles")
## Base flat increases per level
@export var hp_per_level: int = 1
@export var damage_per_level: int = 1
@export var speed_per_level: int = 1
@export var crit_chance_per_level: float = 0.05

@export_category("Unlockable Milestones")
## A dictionary mapping specific levels to custom scripts or behavior modifications
## Example: { SILVER: BehaviorDataResource, GOLD: BehaviorDataResource }
## We'll keep most of these changes to the behavior themselves, e.g. the level scaling is done there
## This is more for if we want to add another ability or unlock something new.
@export var ability_unlocks: Dictionary[Enums.HeroTier, BehaviorData] = {}
@export var new_range: Dictionary[Enums.HeroTier, int] = {}

## Override this method in inherited scripts for unique hero mechanics, if none, skip it
func apply_custom_levelup_logic(hero: Hero, new_level: int) -> void:
	pass
	
func get_stat_upgrade(stat_type : Enums.StatType, tier : Enums.HeroTier = Enums.HeroTier.BRONZE) -> Variant:
	match stat_type:
		Enums.StatType.DAMAGE:
			return damage_per_level
		Enums.StatType.SPEED:
			return speed_per_level 
		Enums.StatType.HP:
			return hp_per_level
		Enums.StatType.RANGE:
			return new_range.get(tier)
		Enums.StatType.CRIT:
			return crit_chance_per_level
	return damage_per_level
