extends Node2D
class_name Hero

@export var hero : HeroData
@export var currentHP : float
@export var currentDamage : float

func _ready() -> void:
	initializeData()
	
func initializeData():
	currentHP = hero.baseHP
	currentDamage = hero.baseDamage
