extends BehaviorData
class_name ModifyStatModifier
# This is if an ability or item should lower the raw stats by x amount, use the modify_value_modifier if you
# want to modify the value of an COMBATEFFECT

@export_group("Stat Settings")
## Choose which core character stat this resource alters
@export var target_stat: Enums.StatType = Enums.StatType.SPEED

## The flat amount to add or subtract from that stat
@export var flat_modifier: float = 0

# A standardized method that every stat item/passive will use
func _execute_stat_modification(stats: Dictionary) -> void:
	if flat_modifier == 0:
		return
		
	# Mutate the dictionary securely without string concatenation
	stats[target_stat] = stats.get(target_stat, 0) + flat_modifier
