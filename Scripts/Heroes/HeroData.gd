extends PurchaseableData
class_name HeroData

@export_group("Tribe and Mechanics")
@export var is_minion : bool = false
@export var tribe : Enums.Tribe
@export var is_legendary_eligible: bool
@export_group("Base Stats")
@export var base_tier : Enums.HeroTier = Enums.HeroTier.BRONZE
@export_range(10,50) var base_HP : int
@export_range(1,10) var base_damage : int
#@export_range(1,10) var base_spellpower : int
@export_range(1,100) var base_speed : int
@export_range(1,3) var base_range : int
@export var base_crit_chance : float = 0.05
@export_group("Base abilities")
@export var base_action : BehaviorData
@export var abilities : Array[BehaviorData]
@export_group("Level Data")
@export var tier_growth_data : HeroGrowthData

func get_starting_stat(stat: Enums.StatType) -> Variant:

	match stat:
		Enums.StatType.MAX_HP:
			return base_HP
		Enums.StatType.DAMAGE: # assuming your enum name maps to base_damage
			return base_damage
		Enums.StatType.SPEED:
			return base_speed
		Enums.StatType.RANGE:
			return base_range
		Enums.StatType.CRIT:
			return base_crit_chance
			
	return 0
