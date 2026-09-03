extends PurchaseableData
class_name BehaviorData

@export_category("Type Settings")
enum BehaviorType { PASSIVE, ACTIVE, BUFF, STAT }
@export var type: BehaviorType = BehaviorType.PASSIVE
enum BehaviorTag {NEUTRAL, BURN, FREEZE, POISON, MARK, STUN, CURSE, ARMOR, POWER}
@export_category("Basic Settings")
@export var value = 0
@export var min_value = 0
@export var max_value = 0
@export_category("Targeting Settings")
@export var target_team: Enums.Team
@export var target_type: Enums.Target
@export var target_count: int = 1
##0 range for self-targeting or if we are not using a custom range
@export_range(0,3) var range : int
@export_category("Crit Settings")
# A probability decimal between 0.0 and 1.0 (e.g., 0.15 for 15%). Leave at 1.0 for guaranteed effects.
@export var proc_chance: float = 1.0
# If this ability procs a critical hit, what should the value be multiplied by? (e.g. 2.0 for double)
@export_range(0,3) var crit_multiplier: float = 1
# Forcefully flips effect.is_crit to true if this behavior procs successfully
@export var force_critical_strike: bool = false
@export var trigger_on_innate_crit: bool = false
#Default is set at action animation, set to null inside the behaviors if no animation should trigger
@export_category("Animation Settings")
@export var animation : String = "action"
@export var animation_duration : float = 0.15
@export_category("Buff Settings")
@export var base_stacks: int = 0 # 0 if not applicable
@export var add_stacks : bool = true # false if the applied buff shouldn't increase existing stacks of same effect
@export var tag : BehaviorTag = BehaviorTag.NEUTRAL
@export var blocks_action : bool = false
@export var behaviors_to_apply: Array[BehaviorData] = []
