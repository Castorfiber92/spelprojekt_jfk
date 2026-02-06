extends Node2D

var a : int = 1
var b : float = 1.25

func _ready() -> void:
	deal_damage()

func deal_damage():
	var damage : float
	damage += a
	print_debug(damage)
	damage = calculate_crit(damage)
	print_debug(damage)

func calculate_crit(dmg : float):
	return dmg*b
