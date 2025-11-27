extends Node2D

var a : int = 1
var b : float = 1.25

func _ready() -> void:
	DealDamage()

func DealDamage():
	var damage : float
	damage += a
	print_debug(damage)
	damage = CalculateCrit(damage)
	print_debug(damage)

func CalculateCrit(dmg : float):
	return dmg*b
