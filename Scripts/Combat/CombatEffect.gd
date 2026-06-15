extends RefCounted
class_name CombatEffect

var source: Hero
var target: Hero
var value: float
var type: String # "DAMAGE", "HEAL", "SHIELD"
var animation : String
var animation_duration : float
var tags: Array[String] = [] # ["fire", "thorns", "melee"]
var buffs: Array[Behavior] = []

# Flags for items to flip, these can be anything, and will need to be updated, but right now
# they are only placeholders, might not even use this
var can_lifesteal: bool = false
var is_crit: bool = false
var bypass_armor: bool = false

func _init(_source: Hero = null, _target: Hero = null, _type : String = "", _value: int = 0, _animation: String = "", _animation_duration: float = 0.15, _buffs: Array[Behavior] = []):
	source = _source
	target = _target
	type = _type
	value = _value
	animation = _animation
	animation_duration = _animation_duration
	for b in _buffs:
		buffs.append(b)
	
## Overridden by children to execute data changes instantly
func execute(_manager: CombatManager) -> void:
	pass

## Overridden by children to handle visuals sequentially
func present(_manager: CombatManager) -> void:
	# Fallback safety timeline hold
	await _manager.get_tree().create_timer(0.01).timeout
