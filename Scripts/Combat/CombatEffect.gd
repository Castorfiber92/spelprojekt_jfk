extends RefCounted
class_name CombatEffect

var source: Hero
var target: Hero
var value: float
var type: String # "DAMAGE", "HEAL", "SHIELD"
var tags: Array[String] = [] # ["fire", "thorns", "melee"]

# Flags for items to flip, these can be anything, and will need to be updated, but right now
# there are only placeholders
var can_lifesteal: bool = false
var is_crit: bool = false
var bypass_armor: bool = false

func _init(_source: Hero, _target: Hero, _type: String, _value: float):
	source = _source
	target = _target
	type = _type
	value = _value
