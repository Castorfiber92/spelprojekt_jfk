extends RefCounted
class_name CombatEffect

var source: HeroSlot
var effect_owner: Hero
var target: HeroSlot
var value: float
var animation : String
var animation_duration : float
var tags: Array[String] = [] # ["fire", "thorns", "melee"]
var buffs: Array[Behavior] = []
	
# Flags for items to flip, these can be anything, and will need to be updated, but right now
# they are only placeholders, might not even use this
var can_lifesteal: bool = false
var is_crit: bool = false
var bypass_armor: bool = false

func _init(_source: HeroSlot = null, _effect_owner: Hero = null, _target: HeroSlot = null, _value: int = 0, _animation: String = "", _animation_duration: float = 0.15, _buffs: Array[Behavior] = []):
	source = _source
	effect_owner = _effect_owner
	target = _target
	value = _value
	animation = _animation
	animation_duration = _animation_duration
	buffs = _buffs
	
## Overridden by children to execute data changes instantly
func execute(_manager: CombatManager) -> Variant:
	return

## Overridden by children to handle visuals sequentially
func present(_manager: CombatManager) -> void:
	# Fallback safety timeline hold
	await _manager.get_tree().create_timer(0.01).timeout
