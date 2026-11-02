extends Node
class_name HeroTierComponent

#signal tiered_up(new_tier: Enums.HeroTier)

@export var growth_blueprint: HeroGrowthData
var parent_hero: Hero

var current_tier: Enums.HeroTier

func tier_up() -> void:
	# Update the basic stats of the runtime hero
	# Carry the change over to the /currentactive combat value
	var stats_to_upgrade = [Enums.StatType.HP, Enums.StatType.DAMAGE, Enums.StatType.SPEED]
	for stat in stats_to_upgrade:
		var amount = growth_blueprint.get_stat_upgrade(stat)
		parent_hero.runtime_base_stats[stat] += amount
		parent_hero.current_stats[stat] += amount

	# 2. Check for Ability/Passive unlocking milestones
	if growth_blueprint.ability_unlocks.has(current_tier):
		parent_hero.learn_behavior(growth_blueprint.ability_unlocks[current_tier])
	# 3. Range
	if growth_blueprint.new_range.has(current_tier):
		var new_range_value = growth_blueprint.get_stat_upgrade(Enums.StatType.RANGE, current_tier)
		parent_hero.runtime_base_stats[Enums.StatType.RANGE] = new_range_value
		parent_hero.current_stats[Enums.StatType.RANGE] = new_range_value
	
	# 4. Fire Custom Script Hooks unique to this hero configuration??
	
	
	#tiered_up.emit(current_tier), might need a signal here


		#--------Shop functionality-------#
func can_merge_with(other_hero: HeroData) -> bool:
	if other_hero == null: return false
	# Must be the exact same character profile
	if name != other_hero.name: return false
	# Cannot merge if already at maximum natural or legendary rank
	if current_tier == Enums.HeroTier.LEGENDARY: return false
	if current_tier == Enums.HeroTier.GOLD and not parent_hero.hero_data.is_legendary_eligible: return false
	
	return true

func advance_tier() -> void:
	# If it is max tier, we do nothing
	if current_tier == Enums.HeroTier.LEGENDARY:
		return
	# If we are at gold but the hero has a legendary upgrade, max it
	if current_tier == Enums.HeroTier.GOLD:
		if parent_hero.hero_data.is_legendary_eligible:
			current_tier = Enums.HeroTier.LEGENDARY
			trigger_legendary_cosmetic_fanfare()
	# If it is just a normal hero, increase the tier up to max of Gold
	else: 
		current_tier += 1
		
	tier_up()

func trigger_legendary_cosmetic_fanfare() -> void:
	# Keep this pure text/data: shop UI layer will read current_tier to play animations later
	print("!!! %s HAS TRANSCENDED TO LEGENDARY STATUS !!!" % name)
	
func get_tier_string() -> String:
	match current_tier:
		Enums.HeroTier.BRONZE: return "Bronze"
		Enums.HeroTier.SILVER: return "Silver"
		Enums.HeroTier.GOLD: return "Gold"
		Enums.HeroTier.LEGENDARY: return "Legendary"
	return ""
