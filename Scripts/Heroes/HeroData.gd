extends PurchaseableData
class_name HeroData

enum HeroTier { BRONZE, SILVER, GOLD, LEGENDARY }
@export_group("Tribe and Mechanics")
@export var is_minion : bool = false
@export var tribe : Enums.Tribe
@export var is_legendary_eligible: bool
@export_group("Base Stats")
@export var current_tier : HeroTier = HeroTier.BRONZE
@export_range(10,50) var base_HP : int
@export_range(1,10) var base_damage : int
#@export_range(1,10) var base_spellpower : int
@export_range(1,100) var base_speed : int
@export_range(1,3) var base_range : int
@export_group("Base abilities")
@export var base_action : Behavior
@export var abilities : Array[Behavior]



#--------Shop functionality-------#
func can_merge_with(other_hero: HeroData) -> bool:
	if other_hero == null: return false
	# Must be the exact same character profile
	if name != other_hero.name: return false
	# Cannot merge if already at maximum natural or legendary rank
	if current_tier == HeroTier.LEGENDARY: return false
	if current_tier == HeroTier.GOLD and not is_legendary_eligible: return false
	
	return true

func advance_tier() -> void:
	match current_tier:
		HeroTier.BRONZE:
			current_tier = HeroTier.SILVER
		HeroTier.SILVER:
			current_tier = HeroTier.GOLD
		HeroTier.GOLD:
			if is_legendary_eligible:
				current_tier = HeroTier.LEGENDARY
				trigger_legendary_cosmetic_fanfare()
			else:
				print("%s is capped at Gold Tier." % name)
		HeroTier.LEGENDARY:
			print("%s is already a Legend." % name)
			
func trigger_legendary_cosmetic_fanfare() -> void:
	# Keep this pure text/data: shop UI layer will read current_tier to play animations later
	print("!!! %s HAS TRANSCENDED TO LEGENDARY STATUS !!!" % name)
	
func get_tier_string() -> String:
	match current_tier:
		HeroTier.BRONZE: return "Bronze"
		HeroTier.SILVER: return "Silver"
		HeroTier.GOLD: return "Gold"
		HeroTier.LEGENDARY: return "Legendary"
	return ""
